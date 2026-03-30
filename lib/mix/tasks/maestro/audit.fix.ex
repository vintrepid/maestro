defmodule Mix.Tasks.Maestro.Audit.Fix do
  @shortdoc "Run audit and auto-fix all fixable findings"

  @moduledoc """
  Runs a full audit (Maestro rules + Giulia AST analysis) and applies all
  available auto-fixes via the Fixer pipeline.

  ## Usage

      mix maestro.audit.fix           # Dry-run: show what would be fixed
      mix maestro.audit.fix --write   # Apply fixes to disk
  """

  use Mix.Task

  alias Maestro.Ops.Audit.Facade, as: Audit

  @impl true
  @spec run([String.t()]) :: :ok
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} = OptionParser.parse(args, strict: [write: :boolean])
    write? = Keyword.get(opts, :write, false)

    Mix.shell().info("Running audit...")

    case Audit.run_audit(approved: true, linter: true, deep: Audit.deep_audit_available?()) do
      {:ok, audit} ->
        Mix.shell().info("Audit complete.")

        if write? do
          {:ok, fixed} = Audit.fix_all(audit)
          Mix.shell().info("Fixed #{fixed} file(s).")

          if fixed > 0 do
            Mix.shell().info("Running mix format...")
            Mix.Task.run("format")
          end
        else
          Mix.shell().info("Dry-run: pass --write to apply fixes.")
        end

      {:error, reason} ->
        Mix.shell().error("Audit failed: #{inspect(reason)}")
    end
  end
end
