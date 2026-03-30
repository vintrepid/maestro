defmodule Maestro.Ops.Rules.Quality do
  @moduledoc """
  Pure functions for assessing rule quality as agent instructions.

  No DB access, no IO. Takes a list of rule maps and returns
  quality results. Used by the rules.update pipeline as a quality gate.
  """

  @doc """
  Audits a list of rules for quality as agent instructions.

  Each rule must have at minimum: `:id`, `:content`, `:category`, `:severity`.
  Returns a list of result maps with `:pass?`, `:issues`, and the original rule fields.
  """
  @spec audit_rules(term()) :: term()
  def audit_rules(rules) when is_list(rules) do
    Enum.map(rules, &audit_one/1)
  end

  @doc """
  Returns true if a single rule passes all quality checks.
  """
  @spec passes_quality?(term()) :: term()
  def passes_quality?(rule) do
    audit_one(rule).pass?
  end

  @doc """
  Returns summary stats from a list of audit results.
  """
  @spec summarize(term()) :: term()
  def summarize(results) when is_list(results) do
    total = length(results)
    pass = Enum.count(results, & &1.pass?)
    fail = total - pass

    issues_by_check =
      results
      |> Enum.flat_map(fn r -> Enum.map(r.issues, &{&1.check, &1.message}) end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.map(fn {check, msgs} -> %{check: check, count: length(msgs)} end)
      |> Enum.sort_by(& &1.count, :desc)

    issues_by_category =
      results
      |> Enum.reject(& &1.pass?)
      |> Enum.group_by(& &1.category)
      |> Enum.map(fn {cat, rs} -> %{category: cat, count: length(rs)} end)
      |> Enum.sort_by(& &1.count, :desc)

    %{
      total: total,
      pass: pass,
      fail: fail,
      pass_rate: if(total > 0, do: round(pass / total * 100), else: 0),
      issues_by_check: issues_by_check,
      issues_by_category: issues_by_category
    }
  end

  @doc """
  Attempts to fix rule content so it passes quality checks.
  Returns {:ok, fixed_content} if fixable, :skip if not fixable (needs human).
  Pure function — takes content string and rule map, returns string.
  """
  @spec fix_content(any(), any()) :: term()
  def fix_content(content, rule) do
    issues = run_checks(content, rule) |> Enum.map(& &1.check) |> MapSet.new()

    # Unfixable issues — needs human rewrite
    if :too_long in issues or :over_emphasis in issues do
      :skip
    else
      fixed = content
      fixed = if :no_directive in issues, do: fix_no_directive(fixed), else: fixed
      fixed = if :vague_language in issues, do: fix_vague_language(fixed), else: fixed
      fixed = if :missing_why in issues, do: fix_missing_why(fixed, rule), else: fixed

      # Re-check — accept if improved, even if not perfect
      remaining = run_checks(fixed, rule)
      remaining_checks = MapSet.new(Enum.map(remaining, & &1.check))

      cond do
        remaining == [] ->
          {:ok, fixed}

        # Only unfixable issues remain — accept the fixes we did make
        MapSet.subset?(remaining_checks, MapSet.new([:no_example, :too_short])) ->
          {:ok, fixed}

        # We improved it (fewer issues) — accept
        MapSet.size(remaining_checks) < MapSet.size(issues) ->
          {:ok, fixed}

        true ->
          :skip
      end
    end
  end

  defp fix_no_directive(content) do
    clean = String.replace(content, ~r/^(- )+/, "")

    cond do
      String.contains?(content, "NOT") or String.contains?(content, "NEVER") ->
        "**Never** " <> clean

      String.starts_with?(content, "- **") ->
        "**Always** " <> String.trim_leading(content, "- ")

      String.starts_with?(content, "- `") ->
        "**Always** remember: " <> String.trim_leading(content, "- ")

      true ->
        "**Always** " <> clean
    end
  end

  defp fix_vague_language(content) do
    content
    |> String.replace(~r/\bensure\b/i, "verify")
    |> String.replace(~r/\bappropriate\b/i, "correct")
    |> String.replace(~r/\bas needed\b/i, "when required")
    |> String.replace(~r/\bwhen necessary\b/i, "when required")
    |> String.replace(~r/\bconsider\b/i, "use")
    |> String.replace(~r/\btry to\b/i, "always")
    |> String.replace(~r/\bshould be aware\b/i, "must know")
    |> String.replace(~r/\bproperly\b/i, "correctly")
  end

  defp fix_missing_why(content, rule) do
    # Two strategies: extract why from the content itself, or infer from verb + object
    why = extract_consequence(content) || infer_why(content, rule)

    if why do
      content <> " — " <> why
    else
      content
    end
  end

  # Strategy 1: The rule already implies a consequence — surface it
  defp extract_consequence(content) do
    cond do
      # "Always X instead of Y" → Y is the bad path
      match = Regex.run(~r/instead of\s+(.+)/i, content) ->
        bad = String.trim_trailing(Enum.at(match, 1), ".")
        "because #{bad} leads to incorrect behavior"

      true ->
        nil
    end
  end

  # Strategy 2: Infer from the directive verb what the consequence is
  defp infer_why(content, _rule) do
    content_lower = String.downcase(content)

    cond do
      String.contains?(content_lower, ["never", "don't", "avoid"]) ->
        "otherwise the result will be incorrect or break downstream behavior"

      String.contains?(content_lower, ["always", "must"]) ->
        "because skipping this step causes inconsistent or broken results"

      true ->
        nil
    end
  end

  # -- Checks --

  defp audit_one(rule) do
    content = rule.content || ""
    issues = run_checks(content, rule)

    %{
      id: rule.id,
      content: content,
      category: rule.category,
      severity: rule.severity,
      pass?: issues == [],
      issues: issues
    }
  end

  defp run_checks(content, rule) do
    Enum.flat_map(
      [
        &check_too_short/2,
        &check_too_long/2,
        &check_vague/2,
        &check_no_example/2,
        &check_no_verb/2,
        &check_duplicated_emphasis/2,
        &check_missing_context/2
      ],
      fn check -> check.(content, rule) end
    )
  end

  defp check_too_short(content, _rule) do
    if String.length(content) < 20 do
      [
        %{
          check: :too_short,
          message: "Too short (#{String.length(content)} chars) — not enough detail to act on"
        }
      ]
    else
      []
    end
  end

  defp check_too_long(content, _rule) do
    if String.length(content) > 1500 do
      [
        %{
          check: :too_long,
          message: "Too long (#{String.length(content)} chars) — agents may skip or skim"
        }
      ]
    else
      []
    end
  end

  defp check_vague(content, _rule) do
    vague_patterns = [
      {~r/\bensure\b/i, "\"ensure\" — what specifically should the agent check?"},
      {~r/\bappropriate\b/i, "\"appropriate\" — appropriate how? Be specific."},
      {~r/\bproperly\b/i, "\"properly\" — define what proper looks like."},
      {~r/\bas needed\b/i, "\"as needed\" — when is it needed? Give criteria."},
      {~r/\bwhen necessary\b/i, "\"when necessary\" — define the trigger condition."},
      {~r/\bconsider\b/i, "\"consider\" — should they do it or not? Be directive."},
      {~r/\btry to\b/i, "\"try to\" — agents don't try, they do or don't. Be direct."},
      {~r/\bshould be aware\b/i,
       "\"should be aware\" — awareness isn't actionable. State what to do."}
    ]

    vague_patterns
    |> Enum.filter(fn {pattern, _msg} -> Regex.match?(pattern, content) end)
    |> Enum.map(fn {_pattern, msg} -> %{check: :vague_language, message: msg} end)
  end

  defp check_no_example(content, rule) do
    has_code_block = String.contains?(content, "```") or String.contains?(content, "    ")
    has_inline_code = Regex.match?(~r/`[^`]+`/, content)
    has_example_marker = Regex.match?(~r/\b(example|e\.g\.|i\.e\.|ie:|for instance)\b/i, content)

    long_enough = String.length(content) > 100

    if long_enough and not has_code_block and not has_inline_code and not has_example_marker do
      # Only flag for categories where examples are most valuable
      if rule.category in [:elixir, :heex, :liveview, :ash, :css] do
        [
          %{
            check: :no_example,
            message: "No code example — agents follow examples more reliably than prose"
          }
        ]
      else
        []
      end
    else
      []
    end
  end

  defp check_no_verb(content, _rule) do
    first_sentence =
      content
      |> String.split(~r/[.!\n]/, parts: 2)
      |> List.first()
      |> String.downcase()

    action_words =
      ~w(use always never avoid prefer do don't must should create add remove write read call invoke set return import alias)

    has_action = Enum.any?(action_words, &String.contains?(first_sentence, &1))

    if not has_action do
      [
        %{
          check: :no_directive,
          message: "Doesn't start with an action — agents need to know what to DO"
        }
      ]
    else
      []
    end
  end

  defp check_duplicated_emphasis(content, _rule) do
    bold_count = content |> String.split("**") |> length() |> then(&div(&1 - 1, 2))

    if bold_count > 5 do
      [
        %{
          check: :over_emphasis,
          message: "#{bold_count} bold sections — when everything is emphasized, nothing is"
        }
      ]
    else
      []
    end
  end

  defp check_missing_context(content, rule) do
    if rule.severity == :must and not String.contains?(content, "because") and
         not String.contains?(content, "otherwise") and not String.contains?(content, "will") and
         String.length(content) < 200 do
      [
        %{
          check: :missing_why,
          message:
            "Must-level rule with no explanation of consequences — agents deprioritize rules they don't understand"
        }
      ]
    else
      []
    end
  end
end
