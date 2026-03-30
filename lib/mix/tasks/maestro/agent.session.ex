defmodule Mix.Tasks.Maestro.Agent.Session do
  @shortdoc "Log an agent work session"
  @moduledoc """
  General-purpose task for logging agent work sessions.
  Run through the task runner to get full session logging.

  ## Usage

      mix maestro.agent.run claude-code maestro.agent.session "Improve /rules page"
      mix maestro.agent.run calvin maestro.agent.session "Fix auth bug"

  The task runner handles session creation, request/response logging,
  and closing the session. This task just records the description.
  """

  use Mix.Task

  @impl true
  @spec run([String.t()]) :: :ok
  def run(args) do
    description = Enum.join(args, " ")
    Mix.shell().info("Session: #{description}")
  end
end
