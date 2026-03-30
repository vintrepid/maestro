defmodule MaestroWeb.TasksLive do
  @moduledoc """
  LiveView for the Tasks page.
  """
  use MaestroWeb, :live_view
  alias Maestro.Ops.Task

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Tasks")
     |> load_tasks()}
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
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
    tasks =
      Task
      |> Ash.Query.sort(updated_at: :desc)
      |> Ash.read!(authorize?: false)
      |> Ash.load!([:display_name], authorize?: false)

    assign(socket, :tasks, tasks)
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="max-w-7xl mx-auto px-8 py-12">
        <div class="flex items-center justify-between mb-8">
          <h1 class="text-4xl font-bold">Tasks</h1>
          <.link navigate={~p"/tasks/new"} class="btn btn-primary">
            <.icon name="hero-plus" class="w-5 h-5" /> New Task
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

  @impl true
  @spec handle_params(map(), String.t(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_params(params, _uri, socket) do
    {:noreply, apply_params(socket, socket.assigns.live_action, params)}
  end

  defp apply_params(socket, _action, _params),
    do: socket
end
