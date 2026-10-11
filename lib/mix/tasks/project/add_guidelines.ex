defmodule Mix.Tasks.Project.AddGuidelines do
  @moduledoc """
  Legacy project setup entry point. Delegates to Maestro Tool's compact
  AGENTS-only bootstrap; no GUIDELINES.md or bulk rulebook is generated.
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  @spec info(any(), any()) :: term()
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{group: :igniter, example: "mix project.add_guidelines", schema: []}
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    Igniter.add_task(igniter, "maestro.guidance.bootstrap", ["--apply"])
  end
end
