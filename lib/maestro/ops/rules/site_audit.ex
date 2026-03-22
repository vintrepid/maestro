defmodule Maestro.Ops.Rules.SiteAudit do
  @moduledoc """
  Pure functions for auditing site pages against approved rules.

  No DB access, no IO. Takes a list of page maps and a list of rules,
  returns per-page audit results. Shared core for mix task and LiveView.
  """

  @doc """
  Discovers pages from the router, filtering to app-owned LiveViews only.
  Returns a list of page maps: %{path, module, source_file, source}.
  """
  def discover_pages(router_module, app_web_prefix) do
    router_module.__routes__()
    |> Enum.filter(&(&1.metadata[:phoenix_live_view] != nil))
    |> Enum.map(fn route ->
      {module, _action, _opts, _extra} = route.metadata[:phoenix_live_view]
      %{path: route.path, module: module}
    end)
    |> Enum.uniq_by(& &1.path)
    |> Enum.filter(&String.starts_with?(to_string(&1.module), to_string(app_web_prefix)))
    |> Enum.map(fn page ->
      source_file = page.module.__info__(:compile)[:source] |> to_string()
      source = File.read!(source_file)
      Map.merge(page, %{source_file: source_file, source: source})
    end)
    |> Enum.sort_by(& &1.path)
  end

  @doc """
  Audits a list of pages against a list of rules.
  Returns a list of page results, each with per-rule findings.
  """
  def audit_pages(pages, rules) do
    checks = Enum.map(rules, &rule_to_check/1)
    applicable_checks = Enum.reject(checks, &(&1.type == :skip))

    Enum.map(pages, fn page ->
      findings = Enum.map(applicable_checks, &check_page(page, &1))
      pass_count = Enum.count(findings, & &1.pass?)
      fail_count = Enum.count(findings, &(not &1.pass?))
      skip_count = length(checks) - length(applicable_checks)

      %{
        path: page.path,
        module: page.module,
        source_file: page.source_file,
        findings: findings,
        pass: pass_count,
        fail: fail_count,
        skip: skip_count,
        total: length(applicable_checks),
        score: if(pass_count + fail_count > 0, do: round(pass_count / (pass_count + fail_count) * 100), else: 100)
      }
    end)
  end

  @doc """
  Summarizes audit results across all pages.
  """
  def summarize(page_results) do
    total_pages = length(page_results)
    avg_score = if total_pages > 0, do: round(Enum.sum(Enum.map(page_results, & &1.score)) / total_pages), else: 0

    all_findings = Enum.flat_map(page_results, & &1.findings)
    total_checks = length(all_findings)
    total_pass = Enum.count(all_findings, & &1.pass?)
    total_fail = total_checks - total_pass

    failing_rules =
      all_findings
      |> Enum.reject(& &1.pass?)
      |> Enum.group_by(& &1.rule_category)
      |> Enum.map(fn {cat, fs} -> %{category: cat, count: length(fs)} end)
      |> Enum.sort_by(& &1.count, :desc)

    %{
      total_pages: total_pages,
      avg_score: avg_score,
      total_checks: total_checks,
      total_pass: total_pass,
      total_fail: total_fail,
      failing_by_category: failing_rules
    }
  end

  # -- Rule to check mapping --
  # Every rule is checkable. The check is derived from the rule's own content:
  #   1. Explicit fields first: lint_pattern, fix_search, fix_type+fix_target
  #   2. Content-derived: directive (Never/Always) + code patterns in backticks
  # Nothing is hardcoded per-rule. The rule content IS the check.

  defp rule_to_check(rule) do
    content = rule.content || ""

    base = %{
      rule_id: rule.id,
      rule_content: String.slice(content, 0, 120),
      rule_category: rule.category,
      type: :skip,
      pattern: nil,
      anti_pattern: nil,
      condition: nil
    }

    build_check(base, rule, content)
  end

  defp build_check(base, rule, content) do
    cond do
      # 1. Explicit lint_pattern — highest priority, already a regex
      is_binary(rule.lint_pattern) and rule.lint_pattern != "" ->
        compile_anti_pattern(base, rule.lint_pattern)

      # 2. Explicit fix_search — regex to find violations
      is_binary(rule.fix_search) and rule.fix_search != "" ->
        compile_anti_pattern(base, rule.fix_search)

      # 3. fix_type: add_callback — check the callback function exists
      rule.fix_type == :add_callback and is_binary(rule.fix_target) and rule.fix_target != "" ->
        func_name = rule.fix_target |> String.split("/") |> hd()
        %{base | type: :requires_pattern, pattern: Regex.compile!("def #{func_name}")}

      # 4. Content-derived: extract directive + code patterns from the rule text
      true ->
        derive_check_from_content(base, content)
    end
  end

  defp compile_anti_pattern(base, pattern_str) do
    case Regex.compile(pattern_str) do
      {:ok, regex} -> %{base | type: :anti_pattern, anti_pattern: regex}
      _ -> base
    end
  end

  # Derive a check from the rule content itself.
  # Extracts the directive (Never/Always/Must) and code patterns from backticks.
  defp derive_check_from_content(base, content) do
    directive = extract_directive(content)
    code_patterns = extract_code_patterns(content)

    case {directive, code_patterns} do
      # "Never X" + code patterns → anti-pattern check (universally applicable)
      {:never, [pattern | _]} ->
        compile_anti_pattern(base, Regex.escape(pattern))

      # "Always X" is conditional — only check if we can extract both
      # the required pattern AND a condition that must be present first.
      # e.g. "Always use to_form" only applies to pages with <.form>
      {:always, [pattern | _]} ->
        case extract_condition(content, pattern) do
          {:ok, condition_regex} ->
            case Regex.compile(Regex.escape(pattern)) do
              {:ok, regex} ->
                %{base | type: :conditional_requires, pattern: regex, condition: condition_regex}
              _ -> base
            end

          :universal ->
            case Regex.compile(Regex.escape(pattern)) do
              {:ok, regex} -> %{base | type: :requires_pattern, pattern: regex}
              _ -> base
            end

          :skip -> base
        end

      # Has code patterns but no clear directive — check if content hints at anti-pattern
      {_, [pattern | _]} when byte_size(pattern) >= 4 ->
        if anti_pattern_language?(content) do
          compile_anti_pattern(base, Regex.escape(pattern))
        else
          base
        end

      # No extractable patterns — skip (pure prose guidance)
      _ -> base
    end
  end

  defp extract_directive(content) do
    cond do
      Regex.match?(~r/\*\*Never\*\*|\bNEVER\b|\bforbidden\b|\bFORBIDDEN\b|\bdo NOT\b|\bdon't\b/i, content) and
        not Regex.match?(~r/\*\*Always\*\*|\bALWAYS\b/i, content) ->
        :never

      Regex.match?(~r/\*\*Always\*\*|\bALWAYS\b|\bMUST\b|\brequired\b/i, content) and
        not Regex.match?(~r/\*\*Never\*\*|\bNEVER\b/i, content) ->
        :always

      true -> nil
    end
  end

  # Extract code patterns from backticks in rule content.
  # Returns the most specific/useful patterns for checking.
  defp extract_code_patterns(content) do
    # Single backtick code spans: `some_code`
    inline_patterns =
      Regex.scan(~r/`([^`]{3,60})`/, content)
      |> Enum.map(fn [_, code] -> clean_code_pattern(code) end)
      |> Enum.reject(&(prose_not_code?(&1) or byte_size(&1) < 3))

    # Return unique patterns, preferring longer/more specific ones
    inline_patterns
    |> Enum.uniq()
    |> Enum.sort_by(&byte_size/1, :desc)
  end

  defp prose_not_code?(text) do
    # Filter out backtick content that's prose or too generic to be a useful check
    common_keywords = ~w(case if cond with for do end else true false nil ok error string integer atom map list tuple)
    downcased = String.downcase(text)

    Regex.match?(~r/^(e\.g\.|i\.e\.|the |a |an |this |that |all |any |some )/i, text) or
      downcased in common_keywords or
      not Regex.match?(~r/[._:\/\(\)<>@#{}\[\]|=]|[A-Z][a-z]+[A-Z]|^[a-z_]+$|^[A-Z]/, text)
  end

  # Determine if an "Always" rule applies universally or conditionally.
  # Returns :universal, {:ok, condition_regex}, or :skip.
  @universal_patterns ~w(handle_params Layouts.app)
  defp extract_condition(content, pattern) do
    cond do
      # Known universal patterns that every LiveView page should have
      Enum.any?(@universal_patterns, &String.contains?(pattern, &1)) ->
        :universal

      # "when building forms" / "for form inputs" → condition: page has forms
      # But only if the rule is actually about building forms, not testing or general advice
      Regex.match?(~r/\bform inputs\b|\bbuilding forms\b|\bto_form\b/i, content) ->
        {:ok, Regex.compile!("<\\.form|<form")}

      # "when using streams" → condition: page uses streams
      Regex.match?(~r/\bstream\b/i, content) ->
        {:ok, Regex.compile!("stream\\(")}

      # "changeset" rules → condition: page uses changesets
      Regex.match?(~r/\bchangeset\b/i, content) ->
        {:ok, Regex.compile!("changeset")}

      # Default: skip — "Always" rules without a clear scope are guidance
      true -> :skip
    end
  end

  # Clean code patterns: remove placeholders, ellipsis, trailing noise
  defp clean_code_pattern(code) do
    code
    |> String.replace(~r/\s*\.{2,}\s*/, "")       # remove ... and ..
    |> String.replace(~r/\s*#.*$/, "")             # remove comments
    |> String.trim_trailing(">")                    # remove trailing > after ellipsis removal
    |> String.trim()
  end

  defp anti_pattern_language?(content) do
    Regex.match?(~r/\bavoid\b|\bnever\b|\bdon't\b|\bdo not\b|\bdeprecated\b|\bforbidden\b|\bunsafe\b/i, content)
  end

  # -- Check execution --

  defp check_page(page, check) do
    result = %{
      rule_id: check.rule_id,
      rule_content: check.rule_content,
      rule_category: check.rule_category,
      pass?: true,
      evidence: []
    }

    case check.type do
      :requires_pattern ->
        if Regex.match?(check.pattern, page.source) do
          result
        else
          %{result | pass?: false, evidence: ["Missing required pattern"]}
        end

      :anti_pattern ->
        matches = Regex.scan(check.anti_pattern, page.source)

        case matches do
          [] -> result
          found ->
            evidence = found |> Enum.take(3) |> Enum.map(fn [m | _] -> "Found: #{String.slice(m, 0, 80)}" end)
            %{result | pass?: false, evidence: evidence}
        end

      :paired_pattern ->
        if Regex.match?(check.pattern, page.source) and not Regex.match?(check.anti_pattern, page.source) do
          %{result | pass?: false, evidence: ["Has #{inspect(check.pattern)} but missing #{inspect(check.anti_pattern)}"]}
        else
          result
        end

      :conditional_requires ->
        # Only check if the condition pattern exists in the source
        if Regex.match?(check.condition, page.source) do
          if Regex.match?(check.pattern, page.source) do
            result
          else
            %{result | pass?: false, evidence: ["Page has forms but missing required pattern"]}
          end
        else
          result  # Condition not met, rule doesn't apply to this page
        end

      :skip ->
        result
    end
  end
end
