defmodule MaestroWeb.ProjectDetailLive do
  @moduledoc """
  LiveView for the Project Detail page.
  """
  use MaestroWeb, :live_view
  require Ash.Query
  alias Maestro.Ops
  import MaestroWeb.Live.Helpers.FileOpener

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    case Ops.get_project_by_slug(slug) do
      nil ->
        {:ok,
         socket |> put_flash(:error, "Project not found") |> push_navigate(to: ~p"/projects")}

      project ->
        project_id = to_string(project.id)

        tasks_query =
          Maestro.Ops.Task
          |> Ash.Query.filter(entity_type == "project" and entity_id == ^project_id)
          |> Ash.Query.sort(updated_at: :desc)
          |> Ash.Query.load(:display_name)

        {:ok,
         socket
         |> assign(:project, project)
         |> assign(:tasks_query, tasks_query)
         |> assign(:page_title, project.name)}
    end
  end

  @impl true
  def handle_event("open_file", %{"path" => path}, socket) do
    open_file(path)
    {:noreply, socket}
  end

  def handle_event("open_in_vscodium", _params, socket) do
    project = socket.assigns.project
    user = socket.assigns.current_user
    editor_command = user.editor_command || "code"
    project_path = "~/dev/#{project.slug}"
    System.cmd(editor_command, [project_path])
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="mx-auto px-8 py-12">
        <div class="mb-8">
          <div class="flex items-center justify-between">
            <h1 class="text-4xl font-bold">{@project.name}</h1>
            <div class="flex items-center gap-2">
              <span class={[
                "badge badge-lg",
                status_badge_class(@project.status)
              ]}>
                {@project.status}
              </span>
            </div>
          </div>

          <p :if={@project.description} class="text-lg text-base-content/70 mt-2">
            {@project.description}
          </p>
        </div>

        <div class="card bg-base-100 shadow-xl mb-6">
          <div class="card-body">
            <div class="flex items-center justify-between mb-4">
              <h2 class="card-title">Tasks</h2>
              <.link
                navigate={~p"/tasks/new?entity_type=Project&entity_id=#{@project.id}"}
                class="btn btn-sm btn-primary"
              >
                <.icon name="hero-plus" class="w-4 h-4" /> New Task
              </.link>
            </div>
            <Cinder.collection
              id="project-tasks-table"
              query={@tasks_query}
              page_size={10}
              theme="daisy_ui"
            >
              <:col :let={task} field="display_name" label="Task" search>
                <.link navigate={~p"/tasks/#{task.id}/edit"} class="link link-primary text-xs">
                  {task.display_name}
                </.link>
              </:col>
              <:col :let={task} field="task_type" label="Type" filter={:select}>
                <span class="badge badge-xs">{task.task_type}</span>
              </:col>
              <:col :let={task} field="status" filter={:select}>
                <span class={"badge badge-xs #{status_class(task.status)}"}>{task.status}</span>
              </:col>
            </Cinder.collection>
          </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div class="lg:col-span-3">
            <div class="card bg-base-100 shadow-xl mb-6">
              <div class="card-body">
                <h2 class="card-title">Project Info</h2>

                <div class="space-y-3">
                  <div>
                    <div class="text-sm text-base-content/60">Web Port</div>
                    <div class="font-mono text-lg">{@project.web_port}</div>
                  </div>

                  <div>
                    <div class="text-sm text-base-content/60">Debugger Port</div>
                    <div class="font-mono text-lg">{@project.debugger_port}</div>
                  </div>

                  <div>
                    <div class="text-sm text-base-content/60">Slug</div>
                    <div class="font-mono">{@project.slug}</div>
                  </div>
                </div>
              </div>
            </div>

            <div class="card bg-base-100 shadow-xl mb-6">
              <div class="card-body">
                <h2 class="card-title">Git Status</h2>
                <.project_git_status project={@project} />
              </div>
            </div>

            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <h2 class="card-title">Quick Links</h2>

                <div class="space-y-2">
                  <a
                    href={"http://localhost:#{@project.web_port}"}
                    target="_blank"
                    class="btn btn-primary btn-block gap-2"
                  >
                    <.icon name="hero-globe-alt" class="w-5 h-5" /> Open Web App
                  </a>

                  <a
                    href={"http://localhost:#{@project.debugger_port}"}
                    target="_blank"
                    class="btn btn-secondary btn-block gap-2"
                  >
                    <.icon name="hero-bug-ant" class="w-5 h-5" /> Open Debugger
                  </a>

                  <a
                    href={@project.github_url}
                    target="_blank"
                    class="btn btn-ghost btn-block gap-2"
                  >
                    <.icon name="hero-code-bracket" class="w-5 h-5" /> View on GitHub
                  </a>

                  <button
                    phx-click="open_in_vscodium"
                    class="btn btn-accent btn-block gap-2"
                  >
                    <.icon name="hero-code-bracket-square" class="w-5 h-5" /> Open in Editor
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="card bg-base-100 shadow-xl mt-6">
          <div class="card-body">
            <h2 class="card-title">Actions</h2>

            <div class="flex gap-4">
              <button class="btn btn-success gap-2">
                <.icon name="hero-play" class="w-5 h-5" /> Start Project
              </button>

              <button class="btn btn-error gap-2">
                <.icon name="hero-stop" class="w-5 h-5" /> Stop Project
              </button>

              <button class="btn btn-warning gap-2">
                <.icon name="hero-arrow-path" class="w-5 h-5" /> Restart Project
              </button>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp project_git_status(assigns) do
    project_path = Path.expand("~/dev/#{assigns.project.slug}")

    ~H"""
    <div id={"git-status-#{@project.id}"} data-project-path={project_path} data-project-id={@project.id} phx-hook="ProjectGitInfoHook">
      <button class="btn btn-sm btn-ghost gap-2">
        <.icon name="hero-code-bracket" class="w-4 h-4" />
        <span id={"git-branch-#{@project.id}"}>Click to load...</span>
      </button>

      <div id={"git-info-#{@project.id}"} class="mt-4" style="display: none;">
        <div class="space-y-2">
          <div>
            <div class="text-sm text-base-content/60">Current Branch</div>
            <div class="font-mono" id={"git-current-#{@project.id}"}></div>
          </div>

          <div id={"git-badges-#{@project.id}"} class="flex gap-2"></div>

          <div id={"git-branches-#{@project.id}"}></div>
        </div>
      </div>
    </div>
    """
  end

  defp status_class(:done), do: "badge-success"
  defp status_class(:in_progress), do: "badge-warning"
  defp status_class(:blocked), do: "badge-error"
  defp status_class(_), do: "badge-ghost"

  defp status_badge_class(status) when status in [:running, "running"], do: "badge-success"
  defp status_badge_class(status) when status in [:stopped, "stopped"], do: "badge-error"
  defp status_badge_class(_), do: "badge-ghost"

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_params(socket, socket.assigns.live_action, params)}
  end

  defp apply_params(socket, _action, _params),
    do: socket
end
