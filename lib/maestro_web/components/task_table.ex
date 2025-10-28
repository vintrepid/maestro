defmodule MaestroWeb.Components.TaskTable do
  use MaestroWeb, :html
  alias Maestro.Repo

  attr :query_fn, :any, required: true
  attr :id, :string, required: true

  def task_table(assigns) do
    tasks = Repo.all(assigns.query_fn.())
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
            <th>Due</th>
            <th>Entity</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          <%= if @tasks == [] do %>
            <tr>
              <td colspan="6" class="text-center text-base-content/60">No tasks yet</td>
            </tr>
          <% end %>
          <%= for task <- @tasks do %>
            <tr>
              <td>{task.title}</td>
              <td><span class="badge badge-sm">{task.task_type}</span></td>
              <td><span class={"badge badge-sm #{status_class(task.status)}"}>{task.status}</span></td>
              <td>
                <%= if task.due_at do %>
                  {Calendar.strftime(task.due_at, "%b %d, %Y")}
                <% else %>
                  <span class="text-base-content/40">—</span>
                <% end %>
              </td>
              <td><span class="text-sm">{task.entity_display_name || task.entity_id}</span></td>
              <td>
                <.link navigate={~p"/tasks/#{task.id}/edit"} class="btn btn-ghost btn-xs">
                  <.icon name="hero-pencil" class="w-4 h-4" />
                </.link>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  defp status_class(:todo), do: "badge-ghost"
  defp status_class(:in_progress), do: "badge-info"
  defp status_class(:done), do: "badge-success"
  defp status_class(:blocked), do: "badge-error"
  defp status_class(_), do: "badge-ghost"
  
  defp get_entity_name("Project", entity_id) when not is_nil(entity_id) do
    case Repo.get(Maestro.Ops.Project, entity_id) do
      nil -> nil
      project -> project.name
    end
  end
  
  defp get_entity_name(_, _), do: nil
end
