defmodule Maestro.Agents.Logger do
  @moduledoc """
  Convenience API for agents to log their activity.
  Used by the agent.run mix task and can be called directly.
  """

  alias Maestro.Agents.{Agent, Session, Request, PubSub}

  @doc """
  Finds or creates an agent, starts a session, and returns both.
  """
  def start_session(agent_name, task_description, opts \\ []) do
    agent = find_or_create_agent(agent_name, opts)

    {:ok, session} =
      Session.create(%{
        agent_id: agent.id,
        task_description: task_description,
        status: :active,
        metadata: Keyword.get(opts, :metadata, %{})
      })

    PubSub.broadcast_session_started(session)
    {:ok, agent, session}
  end

  @doc """
  Logs a request (user prompt, tool call, etc.) within a session.
  """
  def log_request(agent, session, kind, content, opts \\ []) do
    {:ok, request} =
      Request.create(%{
        agent_id: agent.id,
        session_id: session.id,
        kind: kind,
        content: content,
        metadata: Keyword.get(opts, :metadata, %{})
      })

    PubSub.broadcast_request(request)
    request
  end

  @doc """
  Logs the response to a previously created request.
  """
  def log_response(request, response, opts \\ []) do
    {:ok, updated} =
      Request.respond(request, %{
        response: response,
        response_metadata: Keyword.get(opts, :metadata, %{}),
        duration_ms: Keyword.get(opts, :duration_ms)
      })

    PubSub.broadcast_response(updated)
    {:ok, updated}
  end

  @doc """
  Ends a session as completed or failed.
  """
  def end_session(session, status \\ :completed) do
    result =
      case status do
        :completed -> Session.finish(session)
        :failed -> Session.fail(session, %{})
      end

    case result do
      {:ok, session} ->
        PubSub.broadcast_session_ended(session)
        {:ok, session}

      error ->
        error
    end
  end

  defp find_or_create_agent(name, opts) do
    case Agent.by_name(name) do
      {:ok, [agent | _]} ->
        agent

      _ ->
        type = Keyword.get(opts, :type, :custom)
        model = Keyword.get(opts, :model)

        {:ok, agent} =
          Agent.create(%{
            name: name,
            type: type,
            model: model,
            description: "Auto-created by Maestro.Agents.Logger"
          })

        agent
    end
  end
end
