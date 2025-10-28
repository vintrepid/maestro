defmodule MaestroWeb.ResourcesLive do
  use MaestroWeb, :live_view
  import Ecto.Query
  alias Maestro.Repo
  alias Maestro.Resources.Resource

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Resources")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="max-w-7xl mx-auto px-8 py-12">
        <div class="flex items-center justify-between mb-8">
          <h1 class="text-4xl font-bold">Resources</h1>
          <div class="flex gap-2">
            <.link navigate={~p"/resources/import"} class="btn btn-secondary">
              <.icon name="hero-arrow-down-tray" class="w-5 h-5" />
              Import Bookmarks
            </.link>
            <.link navigate={~p"/resources/new"} class="btn btn-primary">
              <.icon name="hero-plus" class="w-5 h-5" />
              New Resource
            </.link>
          </div>
        </div>

        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <MaestroWeb.Components.ResourceTable.resource_table
              id="resources-table"
              query_fn={&list_resources_query/0}
            />
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def list_resources_query do
    from r in Resource, 
      order_by: [desc: r.inserted_at]
  end
end
