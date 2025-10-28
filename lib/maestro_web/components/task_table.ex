defmodule MaestroWeb.Components.TaskTable do
  use MaestroWeb, :html
  alias Maestro.Repo

  attr :query_fn, :any, required: true
  attr :id, :string, required: true

  def task_table(assigns) do
    query = assigns.query_fn.()
    tasks = Repo.all(query)
    |> Maestro.Ops.load!([:display_name])
    
    tasks_with_names = Enum.map(tasks, fn task ->
      Map.put(task, :entity_display_name, get_entity_name(task.entity_type, task.entity_id))
    end)
    assigns = assign(assigns, :tasks, tasks_with_names)

    ~H"""
    <div class="overflow-x-auto">
      <table class="table table-zebra table-pin-rows">
        <thead>
          <tr>
            <th>Title</th>
            <th>Type</th>
            <th>Status</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <%= if @tasks == [] do %>
            <tr>
              <td colspan="4" class="text-center text-base-content/60">No tasks yet</td>
            </tr>
          <% end %>
          <%= for task <- @tasks do %>
            <tr>
              <td>
                <.link navigate={~p"/tasks/#{task.id}/edit"} class="link link-primary">
                  {task.display_name}
                </.link>
              </td>
              <td><span class="badge badge-sm">{task.task_type}</span></td>
              <td><span class={"badge badge-sm #{status_class(task.status)}"}>{task.status}</span></td>
              <td>
                <button
                  phx-click="delete_task"
                  phx-value-id={task.id}
                  data-confirm="Are you sure you want to delete this task?"
                  class="btn btn-ghost btn-xs text-error hover:bg-error hover:text-error-content"
                >
                  <.icon name="hero-trash" class="w-4 h-4" />
                </button>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  attr :tasks, :list, required: true
  attr :id, :string, required: true

  def task_table_static(assigns) do
    tasks_with_names = Enum.map(assigns.tasks, fn task ->
      Map.put(task, :entity_display_name, get_entity_name(task.entity_type, task.entity_id))
    end)
    assigns = assign(assigns, :tasks, tasks_with_names)

    ~H"""
    <div class="overflow-x-auto">
      <table class="table table-zebra table-pin-rows">
        <thead>
          <tr>
            <th>Title</th>
            <th>Type</th>
            <th>Status</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <%= if @tasks == [] do %>
            <tr>
              <td colspan="4" class="text-center text-base-content/60">No tasks yet</td>
            </tr>
          <% end %>
          <%= for task <- @tasks do %>
            <tr>
              <td>
                <.link navigate={~p"/tasks/#{task.id}/edit"} class="link link-primary">
                  {task.display_name}
                </.link>
              </td>
              <td><span class="badge badge-sm">{task.task_type}</span></td>
              <td><span class={"badge badge-sm #{status_class(task.status)}"}>{task.status}</span></td>
              <td>
                <button
                  phx-click="delete_task"
                  phx-value-id={task.id}
                  data-confirm="Are you sure you want to delete this task?"
                  class="btn btn-ghost btn-xs text-error hover:bg-error hover:text-error-content"
                >
                  <.icon name="hero-trash" class="w-4 h-4" />
                </button>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  defp status_class(:todo), do: "badge-ghost"
  defp status_class(:in_progress), do: "badge-success"
  defp status_class(:done), do: "badge-info"
  defp status_class(:blocked), do: "badge-error"
  defp status_class(_), do: "badge-ghost"
  
  defp get_entity_name("Project", entity_id) when not is_nil(entity_id) do
    case Repo.get(Maestro.Ops.Project, entity_id) do
      nil -> nil
      project -> project.name
    end
  end
  
  defp get_entity_name("Task", entity_id) when not is_nil(entity_id) do
    case Maestro.Ops.Task.by_id(entity_id) do
      {:ok, task} -> task |> Maestro.Ops.load!([:display_name]) |> Map.get(:display_name)
      _ -> nil
    end
  end
  
  defp get_entity_name(_, _), do: nil
end
