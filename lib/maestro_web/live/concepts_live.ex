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
     |> assign(:fullscreen, false)}
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
      <div class="max-w-7xl mx-auto px-8 py-12">
        <h1 class="text-4xl font-bold mb-8">Guideline Concept Relationships</h1>
        
        <div class="prose max-w-none mb-8">
          <p>
            This diagram shows how concepts link across different guideline files.
            Understanding these relationships helps identify which guidelines are needed for specific tasks.
          </p>
        </div>

        <div class="card bg-base-100 shadow-xl mb-8">
          <div class="card-body">
            <h2 class="card-title">Latest Guides</h2>
            
            <div class="space-y-4">
              <div class="border-l-4 border-primary pl-4">
                <h3 class="font-semibold">Polymorphic Relations Guide</h3>
                <p class="text-sm text-base-content/70 mt-1">
                  Step-by-step guide for implementing polymorphic relationships using entity_type and entity_id fields.
                  Includes patterns, pitfalls, and a complete checklist.
                </p>
                <div class="mt-2">
                  <span class="badge badge-sm badge-success">Database</span>
                  <span class="badge badge-sm badge-info">Ash</span>
                  <span class="badge badge-sm badge-warning">Relations</span>
                </div>
                <button 
                  phx-click="open_file" 
                  phx-value-path="docs/guides/POLYMORPHIC_RELATIONS.md"
                  class="text-xs mt-2 text-primary hover:text-primary-focus flex items-center gap-1 cursor-pointer"
                >
                  <.icon name="hero-document-text" class="w-4 h-4" />
                  docs/guides/POLYMORPHIC_RELATIONS.md
                  <.icon name="hero-arrow-top-right-on-square" class="w-3 h-3" />
                </button>
              </div>
            </div>
          </div>
        </div>

        <%= if @svg_exists do %>
          <%= if @fullscreen do %>
            <div 
              class="fixed inset-0 z-50 bg-base-100 flex flex-col"
              phx-window-keydown="toggle_fullscreen"
              phx-key="Escape"
            >
              <div class="navbar bg-base-200">
                <div class="navbar-start">
                  <h2 class="text-xl font-bold">Concept DAG</h2>
                </div>
                <div class="navbar-end">
                  <button 
                    phx-click="toggle_fullscreen"
                    class="btn btn-ghost btn-sm"
                  >
                    <.icon name="hero-x-mark" class="w-5 h-5" />
                    Close (ESC)
                  </button>
                </div>
              </div>
              <div class="flex-1 overflow-auto p-8">
                <img 
                  src="/images/concept_dag.svg" 
                  alt="Concept Dependency Graph" 
                  class="w-full h-full object-contain"
                />
              </div>
            </div>
          <% else %>
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <div class="flex items-center justify-between">
                  <h2 class="card-title">Concept DAG</h2>
                  <button 
                    phx-click="toggle_fullscreen"
                    class="btn btn-sm btn-ghost gap-2"
                  >
                    <.icon name="hero-arrows-pointing-out" class="w-4 h-4" />
                    Fullscreen
                  </button>
                </div>
                <div 
                  class="overflow-x-auto cursor-pointer hover:opacity-80 transition-opacity"
                  phx-click="toggle_fullscreen"
                >
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
              <div class="text-sm">
                Run: <code class="bg-base-300 px-2 py-1 rounded">dot -Tsvg agents/CONCEPT_DAG.dot -o priv/static/images/concept_dag.svg</code>
              </div>
            </div>
          </div>
        <% end %>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mt-8">
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">Concept Clusters</h2>
              
              <div class="space-y-4">
                <div>
                  <h3 class="font-semibold text-primary">Core Guidelines</h3>
                  <ul class="list-disc list-inside text-sm">
                    <li>Git Workflow</li>
                    <li>Code Verification</li>
                    <li>Communication</li>
                  </ul>
                </div>

                <div>
                  <h3 class="font-semibold text-success">Database Layer</h3>
                  <ul class="list-disc list-inside text-sm">
                    <li>Primary Keys</li>
                    <li>Ash Resources</li>
                    <li>Polymorphic Relations</li>
                    <li>Data Migrations</li>
                  </ul>
                </div>

                <div>
                  <h3 class="font-semibold text-warning">UI Layer</h3>
                  <ul class="list-disc list-inside text-sm">
                    <li>Phoenix Patterns</li>
                    <li>LiveView</li>
                    <li>DaisyUI Components</li>
                    <li>CSS Standards</li>
                  </ul>
                </div>

                <div>
                  <h3 class="font-semibold text-error">Tools & Infrastructure</h3>
                  <ul class="list-disc list-inside text-sm">
                    <li>CSS Linter</li>
                    <li>LiveTable</li>
                    <li>Fly Deployment</li>
                  </ul>
                </div>

                <div>
                  <h3 class="font-semibold text-secondary">Projects</h3>
                  <ul class="list-disc list-inside text-sm">
                    <li>Calvin (Guide Scheduling)</li>
                    <li>SanJuan (Analytics)</li>
                    <li>Maestro (Coordination)</li>
                  </ul>
                </div>
              </div>
            </div>
          </div>

          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">Key Relationships</h2>
              
              <div class="space-y-4 text-sm">
                <div>
                  <h3 class="font-semibold">Database → UI Flow</h3>
                  <div class="text-base-content/70">
                    Primary Keys → Ash Resources → LiveView → DaisyUI
                  </div>
                  <p class="text-xs mt-1">Database decisions affect UI display</p>
                </div>

                <div>
                  <h3 class="font-semibold">Development Flow</h3>
                  <div class="text-base-content/70">
                    Git Workflow → Code Verification → Communication
                  </div>
                  <p class="text-xs mt-1">Changes go through git, verification, reporting</p>
                </div>

                <div>
                  <h3 class="font-semibold">Component Reuse</h3>
                  <div class="text-base-content/70">
                    LiveTable → DaisyUI + LiveView
                  </div>
                  <p class="text-xs mt-1">Combines patterns for reusable tables</p>
                </div>

                <div>
                  <h3 class="font-semibold">Project Coordination</h3>
                  <div class="text-base-content/70">
                    Maestro → Calvin/SanJuan via Git
                  </div>
                  <p class="text-xs mt-1">Orchestrates work across projects</p>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="card bg-base-100 shadow-xl mt-6">
          <div class="card-body">
            <h2 class="card-title">Example: Adding Task-to-Task Relations</h2>
            <ol class="list-decimal list-inside space-y-2 text-sm">
              <li><strong>Entity Type Options</strong> → Add "Task" to entity_type_options/0</li>
              <li><strong>Display Name</strong> → Update calculation with CAST(? AS integer) for Task</li>
              <li><strong>Entity Resolution</strong> → Add get_entity_name/2 clause for Task in forms and tables</li>
              <li><strong>Sub-tasks Table</strong> → Add child records table on task detail page</li>
              <li><strong>New Sub-task Link</strong> → Pre-fill entity_type=Task&entity_id=(parent_id)</li>
              <li><strong>Test</strong> → Create sub-task, verify display names and hierarchy</li>
            </ol>
            <div class="mt-4">
              <span class="text-xs text-success">✅ Completed in Task #2: new relation</span>
            </div>
          </div>
        </div>

        <div class="mt-8">
          <.link navigate={~p"/"} class="btn btn-ghost">
            <.icon name="hero-arrow-left" class="w-5 h-5" />
            Back to Dashboard
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
