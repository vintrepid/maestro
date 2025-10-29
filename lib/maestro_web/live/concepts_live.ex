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
                    <%= raw(load_svg_content()) %>
                  </div>
                </div>
              <% else %>
                <div class="card bg-base-100 shadow-xl card-compact">
                  <div class="card-body p-0">
                    <div 
                      phx-hook="ShiftClickHook"
                      id="concept-svg-container"
                      class="cursor-pointer hover:opacity-80 transition-opacity"
                    >
                      <%= raw(load_svg_content()) %>
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
      # Generate sub-DAG for this directory
      generate_directory_dag(assigns.current_dir, dir_path)
      
      ~H"""
      <div class="mb-4">
        <p class="text-sm text-base-content/70">Concept map showing relationships between files in this directory. Click nodes to view files.</p>
      </div>
      <div class="card bg-base-100 shadow-xl card-compact">
        <div class="card-body p-0">
          <div class="hover:opacity-80 transition-opacity">
            <%= raw(load_directory_svg(assigns.current_dir)) %>
          </div>
        </div>
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

  defp load_svg_content do
    svg_path = Path.join([Application.app_dir(:maestro), "priv", "static", "images", "concept_dag.svg"])
    if File.exists?(svg_path) do
      File.read!(svg_path)
    else
      ""
    end
  end

  defp generate_directory_dag(dir_name, dir_path) do
    files = File.ls!(dir_path)
    |> Enum.filter(&(!String.starts_with?(&1, ".")))
    |> Enum.sort()
    
    # Generate DOT content for this directory
    dot_content = """
    digraph #{String.replace(dir_name, "-", "_")}Directory {
      rankdir=LR;
      node [shape=box, style=filled, fillcolor=lightblue];
      
      #{Enum.map_join(files, "\n", fn file ->
        id = String.replace(file, ~r/[^a-zA-Z0-9]/, "_")
        label = String.replace(file, "_", " ")
        url = "/concepts/#{dir_name}/#{URI.encode(file)}"
        "  #{id} [label=\"#{label}\" URL=\"#{url}\"];"
      end)}
      
      // Show temporal relationships for session files
      #{generate_session_relationships(files)}
    }
    """
    
    # Write DOT file
    dot_path = "CONCEPT_DAG_#{dir_name}.dot"
    File.write!(dot_path, dot_content)
    
    # Generate SVG
    svg_path = Path.join(["priv", "static", "images", "concept_dag_#{dir_name}.svg"])
    File.mkdir_p!(Path.dirname(svg_path))
    System.cmd("dot", ["-Tsvg", dot_path, "-o", svg_path])
  end

  defp generate_session_relationships(files) do
    # Group related files
    session_learnings = Enum.filter(files, &String.contains?(&1, "SESSION_LEARNINGS"))
    task_summaries = Enum.filter(files, &String.contains?(&1, "TASK"))
    
    relationships = []
    
    # Connect session learnings chronologically
    session_learnings
    |> Enum.sort()
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.each(fn [file1, file2] ->
      id1 = String.replace(file1, ~r/[^a-zA-Z0-9]/, "_")
      id2 = String.replace(file2, ~r/[^a-zA-Z0-9]/, "_")
      relationships = ["  #{id1} -> #{id2} [label=\"followed by\"];" | relationships]
    end)
    
    Enum.join(relationships, "\n")
  end

  defp load_directory_svg(dir_name) do
    svg_path = Path.join([Application.app_dir(:maestro), "priv", "static", "images", "concept_dag_#{dir_name}.svg"])
    if File.exists?(svg_path) do
      File.read!(svg_path)
    else
      "<p>Loading...</p>"
    end
  end
end
