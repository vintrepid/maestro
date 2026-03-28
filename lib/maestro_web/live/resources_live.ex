defmodule MaestroWeb.ResourcesLive do
  @moduledoc """
  Lists resources in a Cinder collection table with filtering and sorting.

  Displays all `Maestro.Resources.Resource` records with columns for title,
  type, URL, and creation date. Supports filtering by resource_type and
  searching by title. Uses URL state sync for bookmarkable filter/sort state.
  """

  use MaestroWeb, :live_view
  use Cinder.UrlSync

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Resources")}
  end

  @impl true
  def handle_params(params, uri, socket) do
    {:noreply, Cinder.UrlSync.handle_params(params, uri, socket)}
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
              <.icon name="hero-arrow-down-tray" class="w-5 h-5" /> Import Bookmarks
            </.link>
            <.link navigate={~p"/resources/new"} class="btn btn-primary">
              <.icon name="hero-plus" class="w-5 h-5" /> New Resource
            </.link>
          </div>
        </div>

        <Cinder.collection
          id="resources-table"
          resource={Maestro.Resources.Resource}
          url_state={@url_state}
          page_size={25}
          theme="daisy_ui"
        >
          <:col :let={resource} field="title" sort search>
            <span class="font-medium">{resource.title}</span>
          </:col>
          <:col :let={resource} field="resource_type" label="Type" sort filter={:select}>
            <span class={"badge badge-sm #{type_class(resource.resource_type)}"}>{resource.resource_type}</span>
          </:col>
          <:col :let={resource} field="url" sort>
            <%= if resource.url do %>
              <a href={resource.url} target="_blank" class="link link-primary text-sm truncate max-w-xs block">
                {resource.url}
              </a>
            <% else %>
              <span class="text-base-content/40">—</span>
            <% end %>
          </:col>
          <:col :let={resource} field="inserted_at" label="Created" sort>
            <span class="text-sm text-base-content/60">
              {Calendar.strftime(resource.inserted_at, "%b %d, %Y")}
            </span>
          </:col>
          <:col :let={resource} label="Actions">
            <div class="flex gap-1">
              <.link navigate={~p"/resources/#{resource.id}/edit"} class="btn btn-ghost btn-xs">
                <.icon name="hero-pencil" class="w-4 h-4" />
              </.link>
              <%= if resource.url do %>
                <a href={resource.url} target="_blank" class="btn btn-ghost btn-xs">
                  <.icon name="hero-arrow-top-right-on-square" class="w-4 h-4" />
                </a>
              <% end %>
            </div>
          </:col>
        </Cinder.collection>
      </div>
    </Layouts.app>
    """
  end

  defp type_class(:file), do: "badge-primary"
  defp type_class(:directory), do: "badge-secondary"
  defp type_class(:website), do: "badge-accent"
  defp type_class(:article), do: "badge-info"
  defp type_class(:conversation), do: "badge-warning"
  defp type_class(_), do: "badge-ghost"
end
