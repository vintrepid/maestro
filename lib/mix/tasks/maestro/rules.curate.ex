defmodule Mix.Tasks.Maestro.Rules.Curate do
  @moduledoc """
  Thin shell for the rules curation pipeline.

  ## Usage

      mix maestro.rules.curate              # Full pipeline
      mix maestro.rules.curate --skip-deps  # Skip deps.update
      mix maestro.rules.curate --skip-sync  # Skip usage_rules.sync
      mix maestro.rules.curate --report     # Just report, no changes
  """

  use Mix.Task
  @shortdoc "Scan deps, sync rules, triage, quality gate, write outputs"

  @spec run([String.t()]) :: :ok
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        strict: [skip_deps: :boolean, skip_sync: :boolean, report: :boolean]
      )

    Maestro.Ops.Rules.Curator.run(opts)
  end
end
