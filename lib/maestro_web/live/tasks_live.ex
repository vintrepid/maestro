defmodule MaestroWeb.TasksLive do
  use MaestroWeb, :live_view
  import Ecto.Query
  alias Maestro.Repo
  alias Maestro.Ops.Task

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Tasks")
     |> load_tasks()}
  end

  @impl true
  def handle_event("delete_task", %{"id" => id}, socket) do
    task = Task.by_id!(String.to_integer(id))
    
    case Task.destroy(task) do
      :ok ->
        {:noreply,
         socket
         |> load_tasks()
         |> put_flash(:info, "Task deleted successfully")}
      
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete task")}
    end
  end

  defp load_tasks(socket) do
    tasks = Repo.all(list_tasks_query())
    |> Maestro.Ops.load!([:display_name])
    assign(socket, :tasks, tasks)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="max-w-7xl mx-auto px-8 py-12">
        <div class="flex items-center justify-between mb-8">
          <h1 class="text-4xl font-bold">Tasks</h1>
          <.link navigate={~p"/tasks/new"} class="btn btn-primary">
            <.icon name="hero-plus" class="w-5 h-5" />
            New Task
          </.link>
        </div>

        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <MaestroWeb.Components.TaskTable.task_table_static
              id="tasks-table"
              tasks={@tasks}
            />
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def list_tasks_query do
    from t in Task, order_by: [desc: t.updated_at]
  end
end
