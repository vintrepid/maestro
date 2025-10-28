defmodule MaestroWeb.AliasesLive do
  use MaestroWeb, :live_view

  @aliases_file Path.expand("~/dev/maestro/agents/ALIASES.md")

  @impl true
  def mount(_params, _session, socket) do
    content = File.read!(@aliases_file)
    
    {:ok,
     socket
     |> assign(:page_title, "Aliases Settings")
     |> assign(:content, content)
     |> assign(:editing, false)}
  end

  @impl true
  def handle_event("edit", _params, socket) do
    {:noreply, assign(socket, :editing, true)}
  end

  def handle_event("save", %{"content" => content}, socket) do
    File.write!(@aliases_file, content)
    
    {:noreply,
     socket
     |> assign(:content, content)
     |> assign(:editing, false)
     |> put_flash(:info, "Aliases saved successfully")}
  end

  def handle_event("cancel", _params, socket) do
    {:noreply, assign(socket, :editing, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="max-w-4xl mx-auto px-8 py-12">
        <div class="mb-8 flex items-center justify-between">
          <h1 class="text-4xl font-bold">Conversational Aliases</h1>
          <%= if !@editing do %>
            <button phx-click="edit" class="btn btn-primary">
              <.icon name="hero-pencil" class="w-5 h-5" />
              Edit
            </button>
          <% end %>
        </div>

        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <%= if @editing do %>
              <textarea
                name="content"
                phx-blur="save"
                class="textarea textarea-bordered font-mono h-96"
              >{@content}</textarea>
              
              <div class="card-actions justify-end">
                <button phx-click="cancel" class="btn btn-ghost">Cancel</button>
                <button
                  phx-click="save"
                  phx-value-content={@content}
                  class="btn btn-primary"
                >
                  Save
                </button>
              </div>
            <% else %>
              <div class="prose max-w-none">
                {raw(Earmark.as_html!(@content))}
              </div>
            <% end %>
          </div>
        </div>

        <div class="alert alert-info mt-6">
          <.icon name="hero-information-circle" class="w-5 h-5" />
          <span>
            Shared across projects at
            <code class="bg-base-300 px-2 py-1 rounded">agents/ALIASES.md</code>
          </span>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
