defmodule MaestroWeb.ProjectDetailLive do
  use MaestroWeb, :live_view
  alias Maestro.Ops

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    case Ops.get_project_by_slug(slug) do
      nil ->
        {:ok, socket |> put_flash(:error, "Project not found") |> push_navigate(to: ~p"/projects")}
      
      project ->
        {:ok,
         socket
         |> assign(:project, project)
         |> assign(:page_title, project.name)}
    end
  end

  @impl true
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
      <div class="max-w-6xl mx-auto px-8 py-12">
        <div class="mb-8">
          <.link navigate={~p"/"} class="btn btn-ghost btn-sm gap-2 mb-4">
            <.icon name="hero-arrow-left" class="w-4 h-4" />
            Back to Dashboard
          </.link>
          
          <div class="flex items-center justify-between">
            <h1 class="text-4xl font-bold">{@project.name}</h1>
            <span class={[
              "badge badge-lg",
              status_badge_class(@project.status)
            ]}>
              {@project.status}
            </span>
          </div>
          
          <p :if={@project.description} class="text-lg text-base-content/70 mt-2">
            {@project.description}
          </p>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div class="card bg-base-100 shadow-xl">
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

          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">Quick Links</h2>
              
              <div class="space-y-2">
                <a 
                  href={"http://localhost:#{@project.web_port}"}
                  target="_blank"
                  class="btn btn-primary btn-block gap-2"
                >
                  <.icon name="hero-globe-alt" class="w-5 h-5" />
                  Open Web App
                </a>
                
                <a 
                  href={"http://localhost:#{@project.debugger_port}"}
                  target="_blank"
                  class="btn btn-secondary btn-block gap-2"
                >
                  <.icon name="hero-bug-ant" class="w-5 h-5" />
                  Open Debugger
                </a>
                
                <a 
                  href={@project.github_url}
                  target="_blank"
                  class="btn btn-ghost btn-block gap-2"
                >
                  <.icon name="hero-code-bracket" class="w-5 h-5" />
                  View on GitHub
                </a>
                
                <button 
                  phx-click="open_in_vscodium"
                  class="btn btn-accent btn-block gap-2"
                >
                  <.icon name="hero-code-bracket-square" class="w-5 h-5" />
                  Open in Editor
                </button>
              </div>
            </div>
          </div>
        </div>

        <div class="card bg-base-100 shadow-xl mt-6">
          <div class="card-body">
            <h2 class="card-title">Actions</h2>
            
            <div class="flex gap-4">
              <button class="btn btn-success gap-2">
                <.icon name="hero-play" class="w-5 h-5" />
                Start Project
              </button>
              
              <button class="btn btn-error gap-2">
                <.icon name="hero-stop" class="w-5 h-5" />
                Stop Project
              </button>
              
              <button class="btn btn-warning gap-2">
                <.icon name="hero-arrow-path" class="w-5 h-5" />
                Restart Project
              </button>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp status_badge_class(status) when status in [:running, "running"], do: "badge-success"
  defp status_badge_class(status) when status in [:stopped, "stopped"], do: "badge-error"
  defp status_badge_class(_), do: "badge-ghost"
end
