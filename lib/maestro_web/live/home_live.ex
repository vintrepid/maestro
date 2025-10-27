defmodule MaestroWeb.HomeLive do
  use MaestroWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Maestro")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="hero min-h-screen bg-base-200">
        <div class="hero-content text-center">
          <div class="max-w-2xl">
            <h1 class="text-6xl font-bold mb-8">
              <span class="text-primary">Maestro</span>
            </h1>
            <p class="text-2xl mb-12 text-base-content/70">
              Your Phoenix Project Orchestration Hub
            </p>
            
            <div class="flex gap-4 justify-center">
              <.link navigate={~p"/projects"} class="btn btn-primary btn-lg gap-2">
                <.icon name="hero-server-stack" class="w-6 h-6" />
                View Projects
              </.link>
              
              <a href="http://localhost:4004" target="_blank" class="btn btn-ghost btn-lg gap-2">
                <.icon name="hero-computer-desktop" class="w-6 h-6" />
                Your Screen
              </a>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
