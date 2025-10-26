defmodule MaestroWeb.DashboardLive do
  use MaestroWeb, :live_view

  alias Maestro.Ops.Project

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(5000, self(), :refresh_projects)
    end

    projects =
      Project
      |> Ash.Query.for_read(:read)
      |> Ash.Query.sort(web_port: :asc)
      |> Ash.read!()

    {:ok, assign(socket, projects: projects)}
  end

  @impl true
  def handle_info(:refresh_projects, socket) do
    projects =
      Project
      |> Ash.Query.for_read(:read)
      |> Ash.Query.sort(web_port: :asc)
      |> Ash.read!()

    {:noreply, assign(socket, projects: projects)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="min-h-screen bg-gradient-to-br from-slate-950 via-blue-950 to-slate-900">
        <div class="container mx-auto px-4 py-12 max-w-7xl">
          <div class="mb-12 text-center">
            <h1 class="text-5xl font-bold text-white mb-4 tracking-tight">
              🎼 Maestro
            </h1>
            <p class="text-xl text-blue-200">
              Development Project Orchestration
            </p>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <div
              :for={project <- @projects}
              class="group relative bg-gradient-to-br from-slate-800/50 to-slate-900/50 backdrop-blur-sm border border-slate-700/50 rounded-xl p-6 hover:border-blue-500/50 transition-all duration-300 hover:shadow-lg hover:shadow-blue-500/20 hover:-translate-y-1"
            >
              <div class="flex items-start justify-between mb-4">
                <div>
                  <h3 class="text-2xl font-bold text-white mb-1">
                    {project.name}
                  </h3>
                  <p class="text-sm text-slate-400">
                    {project.description}
                  </p>
                </div>
                <div class="flex items-center gap-2">
                  <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-slate-700/50 text-slate-300">
                    {status_badge(project.status)}
                  </span>
                </div>
              </div>

              <div class="space-y-3 mb-4">
                <div class="flex items-center gap-2 text-sm">
                  <span class="text-slate-400">Web:</span>
                  <a
                    href={"http://localhost:#{project.web_port}"}
                    target="_blank"
                    class="text-blue-400 hover:text-blue-300 hover:underline font-mono"
                  >
                    localhost:{project.web_port}
                  </a>
                </div>

                <div :if={project.debugger_port} class="flex items-center gap-2 text-sm">
                  <span class="text-slate-400">Debugger:</span>
                  <a
                    href={"http://localhost:#{project.debugger_port}"}
                    target="_blank"
                    class="text-purple-400 hover:text-purple-300 hover:underline font-mono"
                  >
                    localhost:{project.debugger_port}
                  </a>
                </div>

                <div :if={project.github_url} class="flex items-center gap-2 text-sm">
                  <span class="text-slate-400">GitHub:</span>
                  <a
                    href={project.github_url}
                    target="_blank"
                    class="text-green-400 hover:text-green-300 hover:underline truncate"
                  >
                    {project.slug}
                  </a>
                </div>
              </div>

              <div class="pt-4 border-t border-slate-700/50">
                <div class="flex gap-2">
                  <button
                    type="button"
                    class="flex-1 px-4 py-2 bg-blue-600 hover:bg-blue-500 text-white text-sm font-medium rounded-lg transition-colors"
                  >
                    Open
                  </button>
                  <button
                    type="button"
                    class="px-4 py-2 bg-slate-700 hover:bg-slate-600 text-white text-sm font-medium rounded-lg transition-colors"
                  >
                    Logs
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp status_badge(:running), do: "🟢 Running"
  defp status_badge(:stopped), do: "🔴 Stopped"
  defp status_badge(:unknown), do: "⚪ Unknown"
end
