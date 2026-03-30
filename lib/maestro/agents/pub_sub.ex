defmodule Maestro.Agents.PubSub do
  @moduledoc """
  PubSub for real-time agent activity.
  Subscribe to topics to get live updates in the Agent Dashboard.
  """

  @topic "agents:activity"

  @spec topic() :: term()
  def topic, do: @topic
  @spec session_topic(any()) :: term()
  def session_topic(session_id), do: "agents:session:#{session_id}"

  @spec subscribe() :: term()
  def subscribe do
    Phoenix.PubSub.subscribe(Maestro.PubSub, @topic)
  end

  @spec subscribe_session(any()) :: term()
  def subscribe_session(session_id) do
    Phoenix.PubSub.subscribe(Maestro.PubSub, session_topic(session_id))
  end

  @spec broadcast_request(any()) :: term()
  def broadcast_request(request) do
    msg = {:agent_request, request}
    Phoenix.PubSub.broadcast(Maestro.PubSub, @topic, msg)

    if request.session_id do
      Phoenix.PubSub.broadcast(Maestro.PubSub, session_topic(request.session_id), msg)
    end
  end

  @spec broadcast_response(any()) :: term()
  def broadcast_response(request) do
    msg = {:agent_response, request}
    Phoenix.PubSub.broadcast(Maestro.PubSub, @topic, msg)

    if request.session_id do
      Phoenix.PubSub.broadcast(Maestro.PubSub, session_topic(request.session_id), msg)
    end
  end

  @spec broadcast_session_started(map()) :: term()
  def broadcast_session_started(session) do
    Phoenix.PubSub.broadcast(Maestro.PubSub, @topic, {:session_started, session})
  end

  @spec broadcast_session_ended(map()) :: term()
  def broadcast_session_ended(session) do
    Phoenix.PubSub.broadcast(Maestro.PubSub, @topic, {:session_ended, session})
  end
end
