defmodule MaestroWeb.ConceptsLive do
  use MaestroWeb, :live_view
  import MaestroWeb.Live.Helpers.FileOpener

  @impl true
  def mount(_params, _session, socket) do
    svg_path = Path.join([Application.app_dir(:maestro), "priv", "static", "images", "concept_dag.svg"])
    svg_exists = File.exists?(svg_path)
    
    {:ok,
     socket
     |> assign(:page_title, "Guideline Concepts")
     |> assign(:svg_exists, svg_exists)
     |> assign(:fullscreen, false)
     |> assign(:current_dir, nil)
     |> assign(:current_file, nil)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:current_dir, nil)
    |> assign(:current_file, nil)
  end

  defp apply_action(socket, :directory, %{"dir" => dir}) do
    socket
    |> assign(:current_dir, dir)
    |> assign(:current_file, nil)
  end

  defp apply_action(socket, :file, %{"dir" => dir, "file" => file}) do
    socket
    |> assign(:current_dir, dir)
    |> assign(:current_file, URI.decode(file))
  end

  @impl true
  def handle_event("open_file", %{"path" => path}, socket) do
    open_file(path)
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_fullscreen", _params, socket) do
    {:noreply, assign(socket, :fullscreen, !socket.assigns.fullscreen)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="max-w-7xl mx-auto px-4 py-6">
        <%= if @current_file do %>
          <div class="mb-4">
            <.link navigate="/concepts" class="btn btn-sm btn-ghost">← Back to map</.link>
            <.link navigate={"/concepts/#{@current_dir}"} class="btn btn-sm btn-ghost">← Back to {@current_dir}</.link>
          </div>
          <h1 class="text-2xl font-bold mb-4"><%= @current_file %></h1>
          <%= render_file_content(assigns) %>
        <% else %>
          <%= if @current_dir do %>
            <div class="mb-4">
              <.link navigate="/concepts" class="btn btn-sm btn-ghost">← Back to map</.link>
            </div>
            <h1 class="text-2xl font-bold mb-4"><%= String.capitalize(@current_dir) %> Directory</h1>
            <%= render_directory_content(assigns) %>
          <% else %>
            <h1 class="text-2xl font-bold mb-4">Guideline Concept Relationships</h1>
            
            <div class="prose prose-sm max-w-none mb-4">
              <p class="text-sm">
                Click on nodes in the diagram to explore directories and files.
              </p>
            </div>

            <%= if @svg_exists do %>
              <%= if @fullscreen do %>
                <div class="fixed inset-0 z-50 bg-base-100 flex flex-col" phx-window-keydown="toggle_fullscreen" phx-key="Escape">
                  <div class="navbar bg-base-200">
                    <div class="navbar-start"><h2 class="text-xl font-bold">Concept DAG</h2></div>
                    <div class="navbar-end">
                      <button phx-click="toggle_fullscreen" class="btn btn-ghost btn-sm btn-circle">
                        <.icon name="hero-x-mark" class="w-5 h-5" />
                      </button>
                    </div>
                  </div>
                  <div class="flex-1 overflow-auto p-8">
                    <img src="/images/concept_dag.svg" alt="Concept Dependency Graph" class="w-full h-full object-contain" />
                  </div>
                </div>
              <% else %>
                <div class="card bg-base-100 shadow-xl card-compact">
                  <div class="card-body p-0">
                    <div class="cursor-pointer hover:opacity-80 transition-opacity" phx-click="toggle_fullscreen">
                      <img src="/images/concept_dag.svg" alt="Concept Dependency Graph" class="w-full" />
                    </div>
                  </div>
                </div>
              <% end %>
            <% else %>
              <div class="alert alert-warning">
                <.icon name="hero-exclamation-triangle" class="w-6 h-6" />
                <div>
                  <h3 class="font-bold">SVG not generated yet</h3>
                  <div class="text-sm">Run: <code class="bg-base-300 px-2 py-1 rounded">mix concept.update</code></div>
                </div>
              </div>
            <% end %>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp render_directory_content(assigns) do
    agents_dir = Path.expand("~/dev/agents")
    dir_path = Path.join(agents_dir, assigns.current_dir)
    
    if File.dir?(dir_path) do
      files = File.ls!(dir_path)
      |> Enum.filter(&(!String.starts_with?(&1, ".")))
      |> Enum.sort()
      
      assigns = assign(assigns, :files, files)
      
      ~H"""
      <div class="grid grid-cols-1 gap-2">
        <%= for file <- @files do %>
          <.link 
            navigate={"/concepts/#{@current_dir}/#{URI.encode(file)}"} 
            class="card bg-base-100 shadow hover:shadow-lg transition-shadow"
          >
            <div class="card-body p-4">
              <div class="flex items-center gap-2">
                <span class="text-2xl">
                  <%= if String.ends_with?(file, ".json"), do: "📦", else: if String.ends_with?(file, ".md"), do: "📄", else: "📁" %>
                </span>
                <span class="font-medium"><%= file %></span>
              </div>
            </div>
          </.link>
        <% end %>
      </div>
      """
    else
      ~H"""
      <div class="alert alert-warning">
        Directory not found: <%= @current_dir %>
      </div>
      """
    end
  end

  defp render_file_content(assigns) do
    agents_dir = Path.expand("~/dev/agents")
    file_path = Path.join([agents_dir, assigns.current_dir, assigns.current_file])
    
    if File.exists?(file_path) do
      content = File.read!(file_path)
      assigns = assign(assigns, :content, content)
      
      ~H"""
      <div class="prose prose-sm max-w-none">
        <pre class="bg-base-200 p-4 rounded overflow-x-auto"><%= @content %></pre>
      </div>
      """
    else
      ~H"""
      <div class="alert alert-warning">
        File not found: <%= @current_file %>
      </div>
      """
    end
  end
end
