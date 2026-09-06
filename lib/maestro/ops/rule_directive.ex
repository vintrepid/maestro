defmodule Maestro.Ops.RuleDirective do
  @moduledoc """
  Owns the semantic direction of an agent rule independently from its severity.

  A directive says whether a rule requires, forbids, or prefers behavior. Severity
  says how strongly the rule is enforced. Imported rules may still carry legacy
  words such as `Always`, `Never`, or `Prefer` in their content; `parse/1` infers
  the directive from an explicit leading marker and returns marker-free content.

  Output generators render from the persisted directive, so formatting a rule can
  never reverse a prohibition into a requirement.
  """

  @type t :: :require | :forbid | :prefer
  @type severity :: :must | :should | :prefer

  @leading_bullet ~r/^\s*-\s*/u
  @leading_marker ~r/^(?<opening>\*\*)?(?<marker>you\s+are\s+forbidden\s+(?:from|to)|must\s+not|should\s+not|do\s+not|don't|always|never|must|should|prefer|avoid|forbidden)(?<closing>\*\*)?(?:\s*:\s*|\s+)(?<content>.*)$/isu

  @doc """
  Infers direction only from an explicit leading instruction marker.

  Unmarked content defaults to `:require`; inference does not guess from words in
  the middle of a sentence.
  """
  @spec infer(String.t()) :: t()
  def infer(content), do: parse(content).directive

  @doc "Returns the inferred directive and content without a leading marker."
  @spec parse(String.t()) :: %{content: String.t(), directive: t()}
  def parse(content) do
    content = content |> String.replace(@leading_bullet, "") |> String.trim()

    case Regex.named_captures(@leading_marker, content) do
      nil ->
        %{content: content, directive: :require}

      captures ->
        %{
          content: normalize_captured_content(captures),
          directive: marker_directive(captures["marker"])
        }
    end
  end

  @doc "Renders one rule as a Markdown instruction without duplicating markers."
  @spec markdown_line(String.t(), t(), severity()) :: String.t()
  def markdown_line(content, directive, severity) do
    "#{markdown_prefix(directive, severity)} #{parse(content).content}"
  end

  @doc "Renders one compact bundle instruction such as `MUST NOT: deploy`."
  @spec compact_line(String.t(), t(), severity()) :: String.t()
  def compact_line(content, directive, severity) do
    "#{label(directive, severity)}: #{parse(content).content}"
  end

  @doc "Returns the direction-aware enforcement label used by compact exports."
  @spec label(t(), severity()) :: String.t()
  def label(:forbid, :must), do: "MUST NOT"
  def label(:forbid, _severity), do: "SHOULD NOT"
  def label(:prefer, _severity), do: "PREFER"
  def label(:require, :must), do: "MUST"
  def label(:require, :should), do: "SHOULD"
  def label(:require, :prefer), do: "PREFER"

  defp markdown_prefix(:forbid, :must), do: "**NEVER**"
  defp markdown_prefix(:forbid, _severity), do: "- Avoid:"
  defp markdown_prefix(:prefer, _severity), do: "- Prefer:"
  defp markdown_prefix(:require, :must), do: "**ALWAYS**"
  defp markdown_prefix(:require, :should), do: "-"
  defp markdown_prefix(:require, :prefer), do: "- Prefer:"

  defp marker_directive(marker) do
    marker = String.downcase(marker)

    cond do
      marker == "prefer" -> :prefer
      marker in ["always", "must", "should"] -> :require
      true -> :forbid
    end
  end

  defp normalize_captured_content(%{
         "content" => content,
         "opening" => "**",
         "closing" => ""
       }) do
    content
    |> String.trim()
    |> String.trim_trailing("**")
    |> String.trim()
  end

  defp normalize_captured_content(%{"content" => content}), do: String.trim(content)
end
