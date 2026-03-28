defmodule MaestroWeb.TaskApiController do
  @moduledoc """
  Simple JSON API for creating/updating tasks from hooks and scripts.
  Used by the Claude Code UserPromptSubmit hook to automatically log tasks.
  """
  use MaestroWeb, :controller

  def create_or_update(conn, %{"prompt" => prompt} = params) do
    project_slug = params["project"] || "maestro"
    project = Maestro.Ops.get_project_by_slug(project_slug)

    # Find current in-progress task or create new one
    current = current_task()

    task =
      if current do
        # Update existing task with latest prompt context
        notes = (current.notes || "") <> "\n---\n#{prompt}"
        {:ok, t} = Maestro.Ops.Task.update(current, %{notes: String.trim(notes)}, authorize?: false)
        t
      else
        # Create new task
        {:ok, t} = Maestro.Ops.Task.create(%{
          title: String.slice(prompt, 0, 120),
          description: prompt,
          task_type: :feature,
          status: :in_progress,
          entity_type: "Project",
          entity_id: if(project, do: to_string(project.id), else: nil)
        }, authorize?: false)
        t
      end

    json(conn, %{id: task.id, title: task.title, status: task.status})
  end

  defp current_task do
    import Ecto.Query

    Maestro.Repo.one(
      from t in Maestro.Ops.Task,
        where: t.status == :in_progress,
        order_by: [desc: t.updated_at],
        limit: 1
    )
  end
end
