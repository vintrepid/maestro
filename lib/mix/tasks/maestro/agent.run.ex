defmodule Mix.Tasks.Maestro.Agent.Run do
  @shortdoc "Wraps any mix task with agent session logging"
  @moduledoc """
  Runs a mix task inside an agent session, logging requests and responses
  to the Agents domain for real-time dashboard visibility.

  ## Usage

      mix maestro.agent.run <agent_name> <task_name> [task_args...]

  ## Examples

      mix maestro.agent.run claude-code maestro.rules.curate --auto
      mix maestro.agent.run calvin maestro.lint

  This will:
  1. Find or create the agent by name
  2. Start a new session
  3. Log the task invocation as a request
  4. Run the task
  5. Log the result as a response
  6. Close the session
  """

  use Mix.Task

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    case args do
      [agent_name, task_name | task_args] ->
        run_wrapped(agent_name, task_name, task_args)

      _ ->
        Mix.shell().error("Usage: mix maestro.agent.run <agent_name> <task_name> [task_args...]")
    end
  end

  defp run_wrapped(agent_name, task_name, task_args) do
    agent = find_or_create_agent(agent_name)

    {:ok, session} =
      Maestro.Agents.Session.create(%{
        agent_id: agent.id,
        task_description: "mix #{task_name} #{Enum.join(task_args, " ")}",
        status: :active,
        metadata: %{task: task_name, args: task_args}
      })

    Maestro.Agents.PubSub.broadcast_session_started(session)

    # Log the request
    {:ok, request} =
      Maestro.Agents.Request.create(%{
        agent_id: agent.id,
        session_id: session.id,
        kind: :tool_call,
        content: "mix #{task_name} #{Enum.join(task_args, " ")}",
        metadata: %{task: task_name, args: task_args}
      })

    start_time = System.monotonic_time(:millisecond)

    # Run the actual task
    {result, status} =
      try do
        Mix.Task.rerun(task_name, task_args)
        {"Task completed successfully", :completed}
      rescue
        e ->
          {"Error: #{Exception.message(e)}", :failed}
      end

    duration = System.monotonic_time(:millisecond) - start_time

    # Log the response
    Maestro.Agents.Request.respond(request, %{
      response: result,
      response_metadata: %{status: status, exit_code: if(status == :completed, do: 0, else: 1)},
      duration_ms: duration
    })

    # Close the session
    case status do
      :completed -> Maestro.Agents.Session.finish(session)
      :failed -> Maestro.Agents.Session.fail(session, %{metadata: %{error: result}})
    end
    |> case do
      {:ok, session} -> Maestro.Agents.PubSub.broadcast_session_ended(session)
      _ -> :ok
    end

    Mix.shell().info("Agent session logged: #{agent_name} / #{task_name} (#{duration}ms)")
  end

  defp find_or_create_agent(name) do
    case Maestro.Agents.Agent.by_name(name) do
      {:ok, [agent | _]} ->
        agent

      _ ->
        type = infer_type(name)

        {:ok, agent} =
          Maestro.Agents.Agent.create(%{
            name: name,
            type: type,
            description: "Auto-created by mix maestro.agent.run"
          })

        agent
    end
  end

  defp infer_type(name) do
    cond do
      String.contains?(name, "claude") -> :claude_code
      String.contains?(name, "cursor") -> :cursor
      String.contains?(name, "copilot") -> :copilot
      true -> :custom
    end
  end
end
