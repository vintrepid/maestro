defmodule MaestroWeb.DashboardLive do
  use MaestroWeb, :live_view
  use Cinder.UrlSync

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Projects")
      |> assign(:show_inactive, false)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, uri, socket) do
    socket = Cinder.UrlSync.handle_params(params, uri, socket)
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_inactive", _params, socket) do
    {:noreply, assign(socket, :show_inactive, !socket.assigns.show_inactive)}
  end

  @impl true
  def handle_event("delete_project", %{"id" => id}, socket) do
    project = Ash.get!(Maestro.Ops.Project, id, authorize?: false)

    case Maestro.Ops.Project.destroy(project, authorize?: false) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Project deleted successfully")
         |> push_navigate(to: ~p"/projects")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete project")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={assigns[:current_user]}>
      <div class="flex items-center justify-between mb-6">
        <div class="flex items-center gap-4">
          <h1 class="text-2xl font-bold">Projects</h1>
          <label class="flex items-center gap-2 cursor-pointer text-sm text-base-content/60">
            <input
              type="checkbox"
              checked={@show_inactive}
              phx-click="toggle_inactive"
              class="checkbox checkbox-xs"
            />
            Show inactive
          </label>
        </div>
        <.link navigate={~p"/projects/new"} class="btn btn-primary btn-sm gap-1">
          <.icon name="hero-plus" class="w-4 h-4" />
          New Project
        </.link>
      </div>

      <Cinder.collection
        query={projects_query(@show_inactive)}
        id="projects-table"
        url_state={@url_state}
        page_size={25}
        theme="daisy_ui"
        query_opts={[authorize?: false]}
      >
        <:col :let={project} field="name" filter sort>
          <div>
            <.link navigate={~p"/projects/#{project.slug}"} class="link link-primary font-semibold">
              {project.name}
            </.link>
            <div :if={project.prod_url} class="text-xs text-base-content/50">
              <a href={project.prod_url} target="_blank" rel="noopener noreferrer" class="hover:text-base-content/70">
                {project.prod_url}
              </a>
            </div>
          </div>
        </:col>
        <:col :let={project} field="description">{project.description}</:col>
        <:col :let={project} field="status" filter={:select} sort>
          <span class={["badge badge-sm", status_badge(project.status)]}>
            {project.status}
          </span>
        </:col>
        <:col :let={project} field="web_port" sort label="Ports">
          <span class="font-mono text-sm">{project.web_port}</span>
          <span :if={project.debugger_port} class="text-xs text-base-content/40"> / {project.debugger_port}</span>
        </:col>
        <:col :let={project} field="github_url" label="">
          <div class="flex gap-1">
            <a :if={project.github_url} href={project.github_url} target="_blank" rel="noopener noreferrer" class="btn btn-ghost btn-xs" title={project.github_url}>
              <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path fill-rule="evenodd" d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z" clip-rule="evenodd" />
              </svg>
            </a>
            <button
              phx-click="delete_project"
              phx-value-id={project.id}
              data-confirm="Are you sure you want to delete this project?"
              class="btn btn-ghost btn-xs text-error"
              title="Delete project"
            >
              <.icon name="hero-trash" class="w-4 h-4" />
            </button>
          </div>
        </:col>
      </Cinder.collection>
    </Layouts.app>
    """
  end

  defp projects_query(show_inactive) do
    query =
      if show_inactive do
        Maestro.Ops.Project
      else
        Maestro.Ops.Project |> Ash.Query.for_read(:active)
      end

    query |> Ash.Query.sort(status: :asc, name: :asc)
  end

  defp status_badge(:running), do: "badge-success"
  defp status_badge(:stopped), do: "badge-ghost"
  defp status_badge(:inactive), do: "badge-warning"
  defp status_badge(_), do: "badge-ghost"
end
