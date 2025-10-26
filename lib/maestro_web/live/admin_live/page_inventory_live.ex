defmodule MaestroWeb.AdminLive.PageInventoryLive do
  use MaestroWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    search_tag = "h1"

    socket =
      socket
      |> assign(:page_title, "Page Inventory")
      |> assign(:search_tag, search_tag)
      |> assign_pages(search_tag)

    {:ok, socket}
  end

  defp assign_pages(socket, tag) do
    all_pages = get_pages_with_tag(tag)

    socket
    |> assign(:search_tag, tag)
    |> assign(:pages, all_pages)
  end

  defp get_pages_with_tag(tag) do
    routes = [
      {"lib/maestro_web/live/projects_live.ex", "/"},
      {"lib/maestro_web/live/admin_live/tailwind_analysis_live.ex", "/admin/tailwind-analysis"},
      {"lib/maestro_web/live/admin_live/page_inventory_live.ex", "/admin/page-inventory"}
    ]

    routes
    |> Enum.flat_map(fn {file_path, route} ->
      tags = find_all_tags_in_file(file_path, tag)

      Enum.map(tags, fn tag_info ->
        Map.put(tag_info, :route, route)
      end)
    end)
    |> Enum.group_by(& &1.route)
    |> Enum.flat_map(fn {_route, tags} ->
      tags
      |> Enum.with_index()
      |> Enum.map(fn {tag_info, idx} ->
        if idx == 0 do
          tag_info
        else
          Map.put(tag_info, :route, nil)
        end
      end)
    end)
  end

  defp find_all_tags_in_file(file_path, tag) do
    case File.read(file_path) do
      {:ok, content} ->
        regex =
          ~r/<#{Regex.escape(tag)}(?:\s[^>]*)?>.*?<\/#{Regex.escape(tag)}>|<#{Regex.escape(tag)}(?:\s[^>]*)?\s*\/>/s

        Regex.scan(regex, content)
        |> Enum.map(fn [match] ->
          start_pos = :binary.match(content, match) |> elem(0)

          line_number =
            content
            |> String.slice(0, start_pos)
            |> String.split("\n")
            |> length()

          %{tag_html: String.trim(match), line_number: line_number}
        end)

      _ ->
        []
    end
  end

  @impl true
  def handle_event("change_search_tag", %{"tag" => tag}, socket) do
    {:noreply, assign_pages(socket, tag)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div>
        <div class="page-header">
          <h1>Page Inventory</h1>
          <p class="description">
            Search for HTML tags across all pages to identify repeated patterns for extraction to components or global CSS.
          </p>
        </div>

        <.section_card>
          <form
            phx-change="change_search_tag"
            phx-submit="change_search_tag"
            class="form-control search-form"
          >
            <label class="label">
              <span class="label-text">Search for HTML tag:</span>
            </label>
            <input
              type="text"
              name="tag"
              class="input input-bordered input-sm search-input"
              placeholder="h1"
              value={@search_tag}
              phx-debounce="300"
            />
          </form>

          <table class="table table-sm table-zebra">
            <thead>
              <tr>
                <th>Route</th>
                <th>Line</th>
                <th>Tag</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              <%= for page <- @pages do %>
                <tr>
                  <td>
                    <%= if page.route do %>
                      <code>{page.route}</code>
                    <% end %>
                  </td>
                  <td>
                    <%= if page.line_number do %>
                      <span class="line-number">{page.line_number}</span>
                    <% end %>
                  </td>
                  <td>
                    <%= if page.tag_html do %>
                      <code class="truncated">{page.tag_html}</code>
                    <% else %>
                      <span class="empty-state">No {@search_tag}</span>
                    <% end %>
                  </td>
                  <td>
                    <%= if page.tag_html do %>
                      <span class="badge badge-sm badge-success">✓</span>
                    <% else %>
                      <span class="badge badge-sm badge-warning">Missing</span>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </.section_card>
      </div>
    </Layouts.app>
    """
  end
end
