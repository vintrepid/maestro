defmodule Maestro.Ops.AgentDashboard do
  @moduledoc """
  Provides data for the Agent Dashboard.
  Combines current_task.json, git status, and live Agents domain data.
  """

  import Ecto.Query
  alias Maestro.Repo

  @task_file "current_task.json"

  def current_task do
    case File.read(@task_file) do
      {:ok, content} -> Jason.decode!(content)
      _ -> %{}
    end
  end

  @doc "Returns the most recent active session, or nil."
  def active_session do
    Repo.one(
      from s in "agent_sessions",
        where: s.status == "active",
        order_by: [desc: s.inserted_at],
        limit: 1,
        select: %{
          id: type(s.id, :string),
          task_description: s.task_description,
          status: s.status,
          inserted_at: s.inserted_at,
          agent_id: type(s.agent_id, :string)
        }
    )
  end

  @doc "Returns the most recent session (active or completed)."
  def latest_session do
    Repo.one(
      from s in "agent_sessions",
        order_by: [desc: s.inserted_at],
        limit: 1,
        select: %{
          id: type(s.id, :string),
          task_description: s.task_description,
          status: s.status,
          inserted_at: s.inserted_at,
          agent_id: type(s.agent_id, :string)
        }
    )
  end

  @doc "Returns recent requests for the given session, newest first."
  def recent_requests(session_id, limit \\ 10) do
    Repo.all(
      from r in "agent_requests",
        where: r.session_id == type(^session_id, :binary_id),
        order_by: [desc: r.inserted_at],
        limit: ^limit,
        select: %{
          id: type(r.id, :string),
          kind: r.kind,
          content: r.content,
          response: r.response,
          duration_ms: r.duration_ms,
          inserted_at: r.inserted_at
        }
    )
  end

  @doc "Returns the agent name for a given agent_id."
  def agent_name(nil), do: "unknown"
  def agent_name(agent_id) do
    case Repo.one(from a in "agents", where: a.id == type(^agent_id, :binary_id), select: a.name) do
      nil -> "unknown"
      name -> name
    end
  end

  def changed_files do
    case System.cmd("git", ["diff", "--name-only", "HEAD"], stderr_to_stdout: true) do
      {output, 0} ->
        output
        |> String.split("\n", trim: true)
        |> Enum.map(fn path ->
          %{path: path, type: file_type(path)}
        end)

      _ -> []
    end
  end

  def untracked_files do
    case System.cmd("git", ["ls-files", "--others", "--exclude-standard"], stderr_to_stdout: true) do
      {output, 0} ->
        output
        |> String.split("\n", trim: true)
        |> Enum.map(fn path ->
          %{path: path, type: file_type(path)}
        end)

      _ -> []
    end
  end

  def all_files do
    changed = changed_files()
    untracked = untracked_files()

    (changed ++ Enum.map(untracked, &Map.put(&1, :status, :new)))
    |> Enum.uniq_by(& &1.path)
    |> Enum.sort_by(& &1.path)
  end

  defp file_type(path) do
    cond do
      String.ends_with?(path, ".ex") -> :elixir
      String.ends_with?(path, ".heex") -> :heex
      String.ends_with?(path, ".css") -> :css
      String.ends_with?(path, ".js") -> :js
      String.ends_with?(path, ".json") -> :json
      String.ends_with?(path, ".md") -> :markdown
      true -> :other
    end
  end
end
