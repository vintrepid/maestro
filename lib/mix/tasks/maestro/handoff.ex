defmodule Mix.Tasks.Maestro.Handoff do
  @moduledoc """
  Writes current_task.json for the next agent session.

  Gathers live state from the DB and combines it with a session summary
  to create a structured handoff the next agent can pick up immediately.

  ## Usage

      mix maestro.handoff "Built the audit page and fix_it system"
      mix maestro.handoff --status done "Finished PubSub integration"
  """

  use Mix.Task
  @shortdoc "Write current_task.json handoff for next agent session"

  alias Maestro.Ops.Rule
  alias Maestro.Ops.Rules.{Quality, Coverage, SiteAudit}

  @spec run([String.t()]) :: :ok
  def run(args) do
    Mix.Task.run("app.start")

    {opts, rest, _} = OptionParser.parse(args, strict: [status: :string])
    summary = Enum.join(rest, " ")

    if summary == "" do
      Mix.shell().error("Usage: mix maestro.handoff \"description of what you did\"")
      exit({:shutdown, 1})
    end

    status = opts[:status] || "in_progress"
    handoff = build_handoff(summary, status)
    path = "current_task.json"
    File.write!(path, Jason.encode!(handoff, pretty: true))
    Mix.shell().info("Wrote #{path}")
  end

  defp build_handoff(summary, status) do
    %{
      status: status,
      session_date: to_string(Date.utc_today()),
      summary: summary,
      state: gather_state(),
      pending: gather_pending()
    }
  end

  defp gather_state do
    approved = Rule.approved!()
    all_rules = Rule.read!()
    proposed = Enum.filter(all_rules, &(&1.status == :proposed))
    quality_summary = Quality.summarize(Quality.audit_rules(approved))

    audit = gather_audit()

    %{
      approved_rules: length(approved),
      proposed_rules: length(proposed),
      quality_pass_rate: "#{quality_summary.pass_rate}%",
      site_audit: audit
    }
  end

  defp gather_audit do
    try do
      pages = SiteAudit.discover_pages(MaestroWeb.Router, MaestroWeb)
      all_rules = Enum.filter(Rule.read!(), &(&1.status in [:approved, :proposed]))
      results = SiteAudit.audit_pages(pages, all_rules)
      summary = SiteAudit.summarize(results)

      failures =
        results
        |> Enum.flat_map(& &1.findings)
        |> Enum.reject(& &1.pass?)
        |> Enum.group_by(& &1.rule_category)
        |> Enum.map(fn {cat, fs} -> "#{cat}: #{length(fs)}" end)
        |> Enum.sort()

      %{
        pages: summary.total_pages,
        avg_score: "#{summary.avg_score}%",
        failures: failures
      }
    rescue
      _ -> %{pages: 0, avg_score: "not run", failures: []}
    end
  end

  defp gather_pending do
    all_rules = Rule.read!()
    proposed = Enum.filter(all_rules, &(&1.status == :proposed))

    pending = []

    pending =
      if length(proposed) > 0,
        do: pending ++ ["#{length(proposed)} proposed rules need curation at /rules"],
        else: pending

    if pending == [], do: ["Pipeline is clean"], else: pending
  end
end
