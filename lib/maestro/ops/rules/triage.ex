defmodule Maestro.Ops.Rules.Triage do
  @moduledoc """
  Pure function: given rule content and source, returns a triage decision.
  No side effects, no DB access.
  """

  alias Maestro.Ops.Rules.LintExtractor

  @type decision :: %{
          status: :approved | :linter | :retired,
          reason: String.t() | nil,
          lint: map() | nil
        }

  @doc """
  Classify a rule as :approved, :linter, or :retired based on its content.
  Returns a decision map.
  """
  @spec decide(String.t(), String.t() | nil) :: decision()
  def decide(content, source \\ nil) do
    len = String.length(content)
    source = to_string(source)

    cond do
      (lint = LintExtractor.extract(content)) != nil ->
        %{status: :linter, lint: lint}

      retire_reason = retire_reason(content, len, source) ->
        %{status: :retired, reason: retire_reason}

      approve?(content, len, source) ->
        %{status: :approved}

      len < 80 ->
        %{status: :retired, reason: "Too short to be actionable"}

      true ->
        %{status: :approved}
    end
  end

  # --- Retire checks (returns reason string or nil) ---

  defp retire_reason(content, len, _source) do
    cond do
      len < 80 and Regex.match?(~r/^- `[^`]+`\s*-\s*/, content) ->
        "API reference fragment"

      Regex.match?(~r/^- \*\*`\w+[\.\w]*`\*\*\s*-\s*/, content) and len < 120 ->
        "Module reference — use hexdocs"

      Regex.match?(~r/^- `"[\w_]+"` - \w+ \w+$/, content) ->
        "Theme/style option list item"

      Regex.match?(
        ~r/^- \*\*(Read|Create|Update|Destroy|count|avg|max|min|list|sum|first|exists)\*\*/,
        content
      ) and len < 80 ->
        "Generic action type description"

      too_basic?(content) ->
        "Basic knowledge — LLM already knows this"

      Regex.match?(~r/^- `\w+`\s*-\s*(enables?|shows?|includes?|configur)/, content) and len < 100 ->
        "Config option fragment"

      describes_structure?(content) ->
        "Descriptive prose — describes structure, not a rule"

      obsolete_workflow?(content) ->
        "Obsolete workflow — references retired systems"

      ui_copy?(content) ->
        "UI copy or status note — not a rule"

      vague_advice?(content, len) ->
        "Vague advice — no checkable pattern"

      readme_prose?(content) ->
        "README prose — project description, not a rule"

      true ->
        nil
    end
  end

  # --- Approve checks ---

  defp approve?(content, len, source) do
    Regex.match?(~r/\*\*(Always|ALWAYS|Never|NEVER|FORBIDDEN)\*\*/i, content) or
      (String.contains?(content, "```") and len > 150) or
      Regex.match?(~r/\*\*(must|Avoid)\*\*/i, content) or
      (String.starts_with?(source, "ash") and len > 200) or
      (source in ["phoenix", "usage_rules"] and len > 150)
  end

  # --- Basic knowledge filter ---

  @basic_patterns [
    ~r/^- Use `with` for chaining/,
    ~r/^- Use `\{:ok,/,
    ~r/^- Avoid raising exceptions for control flow/,
    ~r/^- Use guard clauses/,
    ~r/^- Prefer keyword lists for options/,
    ~r/^- Use maps for dynamic/,
    ~r/^- Use structs over maps/,
    ~r/^- Name functions descriptively/,
    ~r/^- Prefer `Enum` functions/,
    ~r/^- Prefer to prepend to lists/,
    ~r/^- Use pattern matching over conditional/,
    ~r/^- Prefer multiple function clauses/,
    ~r/^- Use `GenServer\.(call|cast)/,
    ~r/^- Use `Task\.Supervisor`/,
    ~r/^- Use `mix help`/,
    ~r/^- Run tests.*`mix test/,
    ~r/^- Use `dbg/,
    ~r/^- Limit the number of failed tests/,
    ~r/^- Only use macros if/,
    ~r/^- Keep state simple/,
    ~r/^- Handle all expected messages/,
    ~r/^- Set appropriate (task )?timeouts/
  ]

  defp too_basic?(content) do
    Enum.any?(@basic_patterns, &Regex.match?(&1, content))
  end

  # --- Structural/descriptive prose ---
  # Matches content that describes what something IS rather than prescribing what to DO.
  # Directory listings, file descriptions, "contains X" patterns.
  # @prefix handles optional severity markers that quality gate may prepend.
  @prefix ~S"(?:\*\*(?:Always|Never|ALWAYS|NEVER)\*\*\s*)?(?:- )?"

  @structure_patterns [
    # "**dirname/** - Description" or "**file.md** - Description" or "**path/{var}** - ..."
    Regex.compile!(
      @prefix <>
        ~S"\*\*[^*]+\*\*\s*-\s+(Historical|Contains|Shared|Business|Project|All |Start here|Into \d)",
      "i"
    ),
    # "X contains all Y" / "X contains task info"
    Regex.compile!(@prefix <> ~S"\S+ contains all \S+", "i"),
    # "Organized X/ - Into N clusters"
    Regex.compile!(@prefix <> ~S"Organized \w+", "i"),
    # README headers
    ~r/^#\s+(AI Agent|Guidelines|Documentation)/i,
    ~r/^\*\*GitHub Re/
  ]

  defp describes_structure?(content) do
    Enum.any?(@structure_patterns, &Regex.match?(&1, content))
  end

  # --- Obsolete workflow references ---
  # Old systems: bundles, mix session.capacity, CHANGELOG-first branching,
  # task runner UI, mix bundles.track, Ruby git hooks
  @obsolete_patterns [
    # Old task/bundle coordination system
    ~r/mix session\.capacity/,
    ~r/mix bundles\.track/,
    ~r/mix maestro\.task\.request/,
    ~r/bundles?/i,
    ~r/bundling/i,
    ~r/\[task_coordination\]/,
    ~r/\[agent_operations\]/,
    ~r/entity_type:.*entity_id:/,
    # Old git/workflow patterns
    ~r/commit CHANGELOG\.md first/i,
    ~r/Ruby installed.*--no-verify/,
    ~r/--no-verify.*bypass hooks/,
    ~r/ex_cldr backend must be configured/,
    # Stale date/status markers
    ~r/\(curated:\s*\d{4}-\d{2}-\d{2}\)/,
    ~r/\_\(ready\)\_/
  ]

  defp obsolete_workflow?(content) do
    Enum.any?(@obsolete_patterns, &Regex.match?(&1, content))
  end

  # --- UI copy / status notes ---
  @ui_copy_patterns [
    ~r/^- \*\*(Info|Success|Warning|Error) (alert|feedback|message)\*\*/i,
    ~r/^- ✅\s/,
    ~r/"Ready to run\?/,
    ~r/"Task coordinated successfully/,
    ~r/Click '.*' to /
  ]

  defp ui_copy?(content) do
    Enum.any?(@ui_copy_patterns, &Regex.match?(&1, content))
  end

  # --- Vague advice without checkable patterns ---
  # Short rules that describe what to do but have no code, no pattern, no "how"
  @vague_patterns [
    ~r/^- Keep these focused on/,
    ~r/^- One branch per task/,
    ~r/^- List iteration for /
  ]

  defp vague_advice?(content, len) do
    len < 120 and Enum.any?(@vague_patterns, &Regex.match?(&1, content))
  end

  # --- README / intro prose ---
  # Long blocks that are project descriptions, not rules
  defp readme_prose?(content) do
    String.starts_with?(content, "# ") and
      String.length(content) > 300 and
      not Regex.match?(~r/\*\*(Always|Never|ALWAYS|NEVER|Must|Avoid)\*\*/i, content)
  end
end
