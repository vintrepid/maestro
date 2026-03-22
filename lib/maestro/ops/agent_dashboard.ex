defmodule Maestro.Ops.AgentDashboard do
  @moduledoc """
  Provides data for the Agent Dashboard.
  Reads current_task.json and git status to show what the agent is working on.
  """

  @task_file "current_task.json"

  def current_task do
    case File.read(@task_file) do
      {:ok, content} -> Jason.decode!(content)
      _ -> %{}
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
