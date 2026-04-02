defmodule Maestro.Ops.Rules.SessionAnalyzer do
  @moduledoc """
  Analyzes rules in the context of an AgentSession.

  Runs curation checks against the session's derived rule set and produces
  actionable findings. Each finding has a type, severity, and recommendation.

  Checks:
  - `:multi_bullet` — consolidated rules with multiple bullets that should be individual rules
  - `:stale_reference` — references to retired infrastructure (AGENTS.md, old mix tasks)
  - `:bundle_mismatch` — rule content suggests a different bundle than assigned
  - `:duplicate` — rule restates an existing approved rule
  - `:irrelevant` — rule content doesn't match the session's domain scope
  - `:has_user_notes` — rule has curation notes from the user that need processing

  This module is pure analysis — no mutations. The caller decides what to do
  with the findings (present to user, auto-fix, create tasks).
  """

  alias Maestro.Ops.{AgentSession, Rule}

  @stale_patterns [
    {"AGENTS.md", "AGENTS.md is no longer used — replaced by CLAUDE.md"},
    {"mix maestro.update", "mix maestro.update may be stale — verify it still exists"},
    {"live_redirect", "live_redirect is deprecated — use push_navigate"},
    {"live_patch", "live_patch is deprecated — use push_patch"},
    {"LiveTable", "LiveTable is deprecated — use Cinder"}
  ]

  @ui_signals ~w(LiveView template component CSS DaisyUI Tailwind Cinder heex render icon btn badge card modal)
  @maestro_signals ~w(AGENTS.md current_task.json maestro.update agents/ Giulia AshAi)

  @doc """
  Analyzes rules for the given session and returns a list of findings.

  Each finding is a map with:
  - `:rule_id` — the rule being flagged
  - `:check` — atom identifying which check triggered
  - `:severity` — :error, :warning, :info
  - `:message` — human-readable explanation
  - `:recommendation` — what to do about it
  """
  @spec analyze(String.t()) :: [map()]
  def analyze(session_id) do
    session = AgentSession.by_id!(session_id, authorize?: false)
    compatible = compatible_bundles(session.bundle)

    rules =
      Rule.approved!(authorize?: false)
      |> Enum.filter(&(&1.bundle in compatible))

    findings =
      Enum.flat_map(rules, fn rule ->
        []
        |> check_multi_bullet(rule)
        |> check_stale_references(rule)
        |> check_bundle_mismatch(rule, session.bundle)
        |> check_user_notes(rule)
        |> check_duplicates(rule, rules)
      end)

    Enum.sort_by(findings, fn f ->
      sev_rank = case f.severity do :error -> 0; :warning -> 1; _ -> 2 end
      {sev_rank, f.check}
    end)
  end

  @doc """
  Returns a summary of findings grouped by check type.
  """
  @spec summary(String.t()) :: map()
  def summary(session_id) do
    findings = analyze(session_id)

    %{
      total: length(findings),
      by_check: Enum.frequencies_by(findings, & &1.check),
      by_severity: Enum.frequencies_by(findings, & &1.severity),
      errors: Enum.filter(findings, &(&1.severity == :error)),
      warnings: Enum.filter(findings, &(&1.severity == :warning))
    }
  end

  # -- Checks --

  defp check_multi_bullet(findings, rule) do
    lines = String.split(rule.content, "\n")
    bullets = Enum.count(lines, &String.starts_with?(String.trim(&1), "- "))

    if bullets >= 3 do
      # Distinguish "multiple unrelated topics" from "one topic with facets"
      # If the first line names a single topic and bullets elaborate, it's a checklist (lower severity)
      first_line = List.first(lines) || ""
      has_topic_header = String.contains?(first_line, ":") or String.ends_with?(String.trim(first_line), ":")

      {severity, qualifier} =
        if has_topic_header,
          do: {:info, "checklist (single topic with facets)"},
          else: {:warning, "likely multiple unrelated rules consolidated"}

      [%{
        rule_id: rule.id,
        check: :multi_bullet,
        severity: severity,
        message: "Rule has #{bullets} bullet points — #{qualifier}",
        recommendation: if(severity == :warning,
          do: "Break into individual rules. Verify each point is covered by an existing rule.",
          else: "Review: bullets may be fine as a checklist. Only break up if bullets are unrelated topics.")
      } | findings]
    else
      findings
    end
  end

  defp check_stale_references(findings, rule) do
    stale =
      Enum.filter(@stale_patterns, fn {pattern, _msg} ->
        String.contains?(rule.content, pattern)
      end)

    Enum.reduce(stale, findings, fn {_pattern, msg}, acc ->
      [%{
        rule_id: rule.id,
        check: :stale_reference,
        severity: :warning,
        message: msg,
        recommendation: "Retire or update the rule to reference current infrastructure."
      } | acc]
    end)
  end

  defp check_bundle_mismatch(findings, rule, session_bundle) do
    content = rule.content

    ui_score = Enum.count(@ui_signals, &String.contains?(content, &1))
    maestro_score = Enum.count(@maestro_signals, &String.contains?(content, &1))

    cond do
      session_bundle == :model and ui_score >= 2 ->
        [%{
          rule_id: rule.id,
          check: :bundle_mismatch,
          severity: :error,
          message: "Rule mentions #{ui_score} UI terms but is in a model session (bundle: #{rule.bundle})",
          recommendation: "Move to bundle: ui"
        } | findings]

      session_bundle == :model and maestro_score >= 2 ->
        [%{
          rule_id: rule.id,
          check: :bundle_mismatch,
          severity: :error,
          message: "Rule mentions #{maestro_score} Maestro-specific terms but is in bundle: #{rule.bundle}",
          recommendation: "Move to bundle: maestro"
        } | findings]

      true ->
        findings
    end
  end

  defp check_user_notes(findings, rule) do
    if rule.notes && String.length(rule.notes) > 10 do
      [%{
        rule_id: rule.id,
        check: :has_user_notes,
        severity: :info,
        message: "Rule has curation notes (#{String.length(rule.notes)} chars) — read and process before other analysis",
        recommendation: "Read notes first. They may contain specific curation instructions."
      } | findings]
    else
      findings
    end
  end

  defp check_duplicates(findings, rule, all_rules) do
    rule_words = content_words(rule.content)

    dupes =
      all_rules
      |> Enum.reject(&(&1.id == rule.id))
      |> Enum.filter(fn other ->
        other_words = content_words(other.content)
        intersection = MapSet.size(MapSet.intersection(rule_words, other_words))
        union = MapSet.size(MapSet.union(rule_words, other_words))
        union > 0 and intersection / union > 0.6
      end)

    if dupes != [] do
      dupe_ids = Enum.map(dupes, &String.slice(&1.id, 0, 8)) |> Enum.join(", ")

      [%{
        rule_id: rule.id,
        check: :duplicate,
        severity: :warning,
        message: "High similarity with #{length(dupes)} other rule(s): #{dupe_ids}",
        recommendation: "Consolidate or retire duplicates. Keep the most specific version."
      } | findings]
    else
      findings
    end
  end

  # -- Helpers --

  defp content_words(content) do
    content
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s]/, " ")
    |> String.split(~r/\s+/, trim: true)
    |> Enum.reject(&(String.length(&1) < 4))
    |> Enum.reject(&(&1 in ~w(always never should prefer must that this with from have)))
    |> MapSet.new()
  end

  defp compatible_bundles(:model), do: [:universal, :model]
  defp compatible_bundles(:ui), do: [:universal, :ui]
  defp compatible_bundles(_), do: [:universal, :model, :ui, :devops]
end
