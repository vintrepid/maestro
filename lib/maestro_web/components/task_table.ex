defmodule MaestroWeb.Components.TaskTable do
  use MaestroWeb, :html
  alias Maestro.Repo
  alias Phoenix.LiveView.JS

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
      <table class="table table-zebra table-xs">
        <thead>
          <tr>
            <th class="w-8"></th>
            <th class="w-full">Title</th>
            <th class="whitespace-nowrap">Type</th>
            <th class="whitespace-nowrap">Status</th>
            <th class="w-8"></th>
          </tr>
        </thead>
        <tbody>
          <%= if @tasks == [] do %>
            <tr>
              <td colspan="5" class="text-center text-base-content/60">No tasks yet</td>
            </tr>
          <% end %>
          <%= for task <- @tasks do %>
            <tr>
              <td class="py-1">
                <button 
                  type="button"
                  phx-click={toggle_description("desc-#{task.id}")}
                  class="btn btn-ghost btn-xs p-0"
                >
                  <.icon name="hero-chevron-right" class="w-3 h-3 transition-transform" id={"chevron-#{task.id}"} />
                </button>
              </td>
              <td class="py-1">
                <.link navigate={~p"/tasks/#{task.id}/edit"} class="link link-primary text-xs">
                  {task.display_name}
                </.link>
              </td>
              <td class="py-1"><span class="badge badge-xs">{task.task_type}</span></td>
              <td class="py-1"><span class={"badge badge-xs #{status_class(task.status)}"}>{task.status}</span></td>
              <td class="py-1">
                <button
                  phx-click="delete_task"
                  phx-value-id={task.id}
                  data-confirm="Delete?"
                  class="btn btn-ghost btn-xs text-error"
                >
                  <.icon name="hero-trash" class="w-3 h-3" />
                </button>
              </td>
            </tr>
            <%= if task.description do %>
              <tr id={"desc-#{task.id}"} style="display: none;">
                <td></td>
                <td colspan="4" class="py-1">
                  <div class="text-xs text-base-content/70 pl-2 prose prose-xs max-w-none">
                    {raw(Earmark.as_html!(task.description || ""))}
                  </div>
                </td>
              </tr>
            <% end %>
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
      <table class="table table-zebra table-xs">
        <thead>
          <tr>
            <th class="w-full">Title</th>
            <th class="whitespace-nowrap">Type</th>
            <th class="whitespace-nowrap">Status</th>
            <th class="w-8"></th>
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
              <td class="py-1">
                <.link navigate={~p"/tasks/#{task.id}/edit"} class="link link-primary text-xs">
                  {task.display_name}
                </.link>
              </td>
              <td class="py-1"><span class="badge badge-xs">{task.task_type}</span></td>
              <td class="py-1"><span class={"badge badge-xs #{status_class(task.status)}"}>{task.status}</span></td>
              <td class="py-1">
                <button
                  phx-click="delete_task"
                  phx-value-id={task.id}
                  data-confirm="Delete?"
                  class="btn btn-ghost btn-xs text-error"
                >
                  <.icon name="hero-trash" class="w-3 h-3" />
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
  
  defp toggle_description(row_id) do
    JS.toggle(to: "##{row_id}")
    |> JS.toggle_class("rotate-90", to: "#chevron-" <> String.replace(row_id, "desc-", ""))
  end
  
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
