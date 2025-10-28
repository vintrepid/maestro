defmodule MaestroWeb.Components.ResourceTable do
  use MaestroWeb, :html
  alias Maestro.Repo

  attr :query_fn, :any, required: true
  attr :id, :string, required: true

  def resource_table(assigns) do
    query = assigns.query_fn.()
    resources = Repo.all(query)
    
    assigns = assign(assigns, :resources, resources)

    ~H"""
    <div class="overflow-x-auto">
      <table class="table table-zebra table-pin-rows">
        <thead>
          <tr>
            <th>Title</th>
            <th>Type</th>
            <th>URL</th>
            <th>Tags</th>
            <th>Created</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          <%= if @resources == [] do %>
            <tr>
              <td colspan="6" class="text-center text-base-content/60">No resources yet</td>
            </tr>
          <% end %>
          <%= for resource <- @resources do %>
            <tr>
              <td class="font-medium">{resource.title}</td>
              <td><span class={"badge badge-sm #{type_class(resource.resource_type)}"}>{resource.resource_type}</span></td>
              <td>
                <%= if resource.url do %>
                  <a href={resource.url} target="_blank" class="link link-primary text-sm truncate max-w-xs block">
                    {resource.url}
                  </a>
                <% else %>
                  <span class="text-base-content/40">—</span>
                <% end %>
              </td>
              <td>
                <div class="flex gap-1 flex-wrap">
                  <%= if Ecto.assoc_loaded?(resource.tags) and is_list(resource.tags) do %>
                    <%= for tag <- resource.tags do %>
                      <span class="badge badge-sm" style={"background-color: #{tag.color || "#666"}; color: white;"}>
                        {tag.name}
                      </span>
                    <% end %>
                  <% else %>
                    <span class="text-base-content/40 text-sm">—</span>
                  <% end %>
                </div>
              </td>
              <td class="text-sm text-base-content/60">
                {Calendar.strftime(resource.inserted_at, "%b %d, %Y")}
              </td>
              <td>
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
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  defp type_class(:file), do: "badge-primary"
  defp type_class(:directory), do: "badge-secondary"
  defp type_class(:website), do: "badge-accent"
  defp type_class(:article), do: "badge-info"
  defp type_class(:conversation), do: "badge-warning"
  defp type_class(_), do: "badge-ghost"
end
