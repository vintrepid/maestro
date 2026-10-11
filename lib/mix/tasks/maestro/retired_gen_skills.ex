defmodule Mix.Tasks.Maestro.Gen.Skills do
  use Mix.Task
  @shortdoc "Retired: rule clusters are reference material, not executable skills"
  @moduledoc "Use shared Maestro Tool generators/checks. Catalog exports remain searchable reference; do not repackage prose as startup instructions."

  @impl true
  def run(_args) do
    Mix.raise(
      "Rule-cluster skill generation is retired. Use Maestro Tool's shared tasks and checks; use maestro.rules.export only for reference exports."
    )
  end
end
