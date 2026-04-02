defmodule Maestro.Agents.Facade do
  @moduledoc """
  Facade for the Agents domain, used by AgentsLive.

  Encapsulates all data-fetching, PubSub subscription, and row-conversion
  logic so the LiveView remains a thin rendering shell. Every function
  returns plain maps suitable for LiveView streams (string `:id` keys).
  """

  require Ash.Query

  alias Maestro.Agents.{Agent, Session, Request, PubSub}

  # --- PubSub ---

  @doc "Subscribe the calling process to agent activity broadcasts."
  @spec subscribe() :: :ok | {:error, term()}
  def subscribe, do: PubSub.subscribe()

  # --- Queries ---

  @doc "List all registered agents, sorted by name."
  @spec list_agents() :: [map()]
  def list_agents do
    Agent
    |> Ash.Query.sort(name: :asc)
    |> Ash.read!(authorize?: false)
    |> Enum.map(fn a ->
      %{
        id: to_string(a.id),
        name: a.name,
        type: a.type,
        model: a.model,
        description: a.description
      }
    end)
  end

  @doc "List the 50 most recent sessions, newest first."
  @spec list_recent_sessions() :: [map()]
  def list_recent_sessions do
    Session
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(50)
    |> Ash.read!(authorize?: false)
    |> Enum.map(&to_session_row/1)
  end

  @doc "List recent requests across all sessions."
  @spec list_recent_requests() :: [map()]
  def list_recent_requests do
    Enum.map(Request.recent!(authorize?: false), &to_request_row/1)
  end

  @doc "List requests belonging to a specific session."
  @spec list_requests_for_session(String.t()) :: [map()]
  def list_requests_for_session(session_id) do
    Enum.map(Request.by_session!(session_id, authorize?: false), &to_request_row/1)
  end

  @doc """
  Read the session capacity hint from SESS_CAP.md in the project root.
  Returns `nil` when the file does not exist.
  """
  @spec read_session_capacity() :: String.t() | nil
  def read_session_capacity do
    capacity_file = Path.join([File.cwd!(), "SESS_CAP.md"])

    if File.exists?(capacity_file) do
      capacity_file |> File.read!() |> String.trim()
    else
      nil
    end
  end

  # --- Row converters ---

  @doc "Convert a `Request` struct (or PubSub message payload) to a stream-ready map."
  @spec to_request_row(struct() | map()) :: map()
  def to_request_row(request) do
    %{
      id: to_string(request.id),
      kind: request.kind,
      content: request.content,
      response: request.response,
      duration_ms: request.duration_ms,
      inserted_at: request.inserted_at,
      responded_at: request.responded_at,
      metadata: request.metadata || %{}
    }
  end

  @doc "Convert a `Session` struct (or PubSub message payload) to a stream-ready map."
  @spec to_session_row(struct() | map()) :: map()
  def to_session_row(session) do
    %{
      id: to_string(session.id),
      task_description: session.task_description,
      status: session.status,
      inserted_at: session.inserted_at,
      ended_at: session.ended_at
    }
  end
end
