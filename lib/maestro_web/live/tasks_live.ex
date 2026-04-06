defmodule MaestroWeb.TasksLive do
  @moduledoc """
  Lists tasks in a Cinder collection table.

  Tasks are attached to entities (projects, rules, etc). The display_name
  calculation shows `task_type: entity_name`. Clicking a task navigates
  to its attached entity, not to the task itself.
  """
  use MaestroWeb, :live_view
  use Cinder.UrlSync

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Tasks")}
  end

  @impl true
  def handle_params(params, uri, socket) do
    {:noreply, Cinder.UrlSync.handle_params(params, uri, socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="max-w-7xl mx-auto px-8 py-12">
        <h1 class="text-4xl font-bold mb-8">Tasks</h1>

        <Cinder.collection
          id="tasks-table"
          query={Maestro.Ops.Task |> Ash.Query.sort(updated_at: :desc) |> Ash.Query.load(:display_name)}
          url_state={@url_state}
          page_size={25}
          theme="daisy_ui"
        >
          <:col :let={task} field="display_name" label="Task" sort search>
            <.link navigate={entity_path(task)} class="link link-primary">
              {task.display_name}
            </.link>
          </:col>
          <:col :let={task} field="task_type" label="Type" sort filter={:select}>
            <span class="badge badge-sm">{task.task_type}</span>
          </:col>
          <:col :let={task} field="status" sort filter={:select}>
            <span class={"badge badge-sm #{status_class(task.status)}"}>{task.status}</span>
          </:col>
          <:col :let={task} field="entity_type" label="Entity" sort filter={:select}>
            {task.entity_type}
          </:col>
          <:col :let={task} field="updated_at" label="Updated" sort>
            <span class="text-sm text-base-content/60">
              {Calendar.strftime(task.updated_at, "%b %d, %Y")}
            </span>
          </:col>
        </Cinder.collection>
      </div>
    </Layouts.app>
    """
  end

  defp entity_path(%{entity_type: "rule", entity_id: id}), do: ~p"/rules/#{id}"

  defp entity_path(%{entity_type: "project", entity_id: id}) do
    case Maestro.Ops.Project.by_id(id, authorize?: false) do
      {:ok, project} -> ~p"/projects/#{project.slug}"
      _ -> ~p"/projects"
    end
  end

  defp entity_path(task), do: ~p"/tasks/#{task.id}/edit"

  defp status_class(:done), do: "badge-success"
  defp status_class(:in_progress), do: "badge-warning"
  defp status_class(:blocked), do: "badge-error"
  defp status_class(_), do: "badge-ghost"
end
