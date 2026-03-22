defmodule Maestro.Ops.Rules.Triage do
  @moduledoc """
  Pure function: given rule content and source, returns a triage decision.
  No side effects, no DB access.
  """

  alias Maestro.Ops.Rules.LintExtractor

  @type decision :: %{status: :approved | :linter | :retired, reason: String.t() | nil, lint: map() | nil}

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

      len > 200 -> %{status: :approved}
      len < 80 -> %{status: :retired, reason: "Too short to be actionable"}
      true -> %{status: :approved}
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

      Regex.match?(~r/^- \*\*(Read|Create|Update|Destroy|count|avg|max|min|list|sum|first|exists)\*\*/, content) and len < 80 ->
        "Generic action type description"

      too_basic?(content) ->
        "Basic knowledge — LLM already knows this"

      Regex.match?(~r/^- `\w+`\s*-\s*(enables?|shows?|includes?|configur)/, content) and len < 100 ->
        "Config option fragment"

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
end
