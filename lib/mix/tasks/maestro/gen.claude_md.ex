defmodule Mix.Tasks.Maestro.Gen.ClaudeMd do
  @shortdoc "Retired: use maestro.guidance.bootstrap for AGENTS-only instructions"
  @moduledoc """
  This old entry point deliberately refuses to export the rule corpus into
  startup instructions. Use `mix maestro.guidance.bootstrap --apply` instead.
  Rule catalog exports remain available as reference material only.
  """
  use Mix.Task

  @impl true
  def run(_args) do
    Mix.raise(
      "CLAUDE.md generation is retired. Use mix maestro.guidance.bootstrap --apply for a compact AGENTS.md."
    )
  end
end
