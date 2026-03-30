defmodule MaestroWeb.Components.GiuliaSkillsCatalog do
  @moduledoc """
  Collapsible Giulia skills catalog component.

  Displays all 74 skills grouped by category with search filtering.
  Fetches data from Giulia's discovery API via GiuliaClient.
  """
  use MaestroWeb, :live_component

  alias Maestro.Ops.Rules.GiuliaClient

  @impl true
  @spec mount(term()) :: term()
  def mount(socket) do
    {:ok,
     socket
     |> assign(:expanded, false)
     |> assign(:search, "")
     |> assign(:selected_category, nil)
     |> assign(:categories, [])
     |> assign(:skills, [])}
  end

  @impl true
  @spec update(term(), term()) :: term()
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    socket =
      if socket.assigns.categories == [] and socket.assigns.expanded do
        load_data(socket)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  @spec handle_event(term(), term(), term()) :: term()
  def handle_event("toggle", _params, socket) do
    expanded = not socket.assigns.expanded

    socket =
      if expanded and socket.assigns.categories == [] do
        load_data(socket)
      else
        socket
      end

    {:noreply, assign(socket, :expanded, expanded)}
  end

  @spec handle_event(term(), term(), term()) :: term()
  def handle_event("filter_category", %{"category" => cat}, socket) do
    selected = if cat == socket.assigns.selected_category, do: nil, else: cat
    skills = if selected, do: GiuliaClient.fetch_skills(selected), else: GiuliaClient.fetch_skills()
    {:noreply, socket |> assign(:selected_category, selected) |> assign(:skills, skills)}
  end

  @spec handle_event(term(), term(), term()) :: term()
  def handle_event("search", %{"search" => query}, socket) do
    query = String.trim(query)

    skills =
      if query == "" do
        if socket.assigns.selected_category,
          do: GiuliaClient.fetch_skills(socket.assigns.selected_category),
          else: GiuliaClient.fetch_skills()
      else
        GiuliaClient.search_skills(query)
      end

    {:noreply, socket |> assign(:search, query) |> assign(:skills, skills)}
  end

  @impl true
  @spec render(term()) :: term()
  def render(assigns) do
    ~H"""
    <div id={@id} class="mb-4">
      <button
        phx-click="toggle"
        phx-target={@myself}
        class="btn btn-ghost btn-sm gap-2"
      >
        <.icon
          name={if @expanded, do: "hero-chevron-down", else: "hero-chevron-right"}
          class="w-4 h-4"
        />
        <span class="text-sm font-semibold">Giulia Skills Catalog</span>
        <%= if @categories != [] do %>
          <span class="badge badge-info badge-sm">
            {Enum.reduce(@categories, 0, fn c, acc -> acc + c["count"] end)} skills
          </span>
        <% end %>
      </button>

      <%= if @expanded do %>
        <div class="mt-2 p-4 bg-base-200 rounded-lg">
          <div class="flex items-center gap-2 mb-3 flex-wrap">
            <form phx-change="search" phx-target={@myself} id="giulia-skills-search-form">
              <input
                type="text"
                name="search"
                value={@search}
                placeholder="Search skills..."
                class="input input-sm input-bordered w-48"
                phx-debounce="300"
              />
            </form>
            <%= for cat <- @categories do %>
              <button
                phx-click="filter_category"
                phx-target={@myself}
                phx-value-category={cat["category"]}
                class={[
                  "badge badge-sm cursor-pointer",
                  if(@selected_category == cat["category"],
                    do: "badge-primary",
                    else: "badge-outline"
                  )
                ]}
              >
                {cat["category"]} ({cat["count"]})
              </button>
            <% end %>
          </div>

          <div class="max-h-64 overflow-y-auto">
            <table class="table table-xs table-zebra">
              <thead>
                <tr>
                  <th>Category</th>
                  <th>Endpoint</th>
                  <th>Intent</th>
                </tr>
              </thead>
              <tbody>
                <%= for skill <- @skills do %>
                  <tr>
                    <td>
                      <span class={["badge badge-xs", category_badge(skill["category"])]}>
                        {skill["category"]}
                      </span>
                    </td>
                    <td class="font-mono text-xs">{skill["endpoint"]}</td>
                    <td class="text-xs">{skill["intent"]}</td>
                  </tr>
                <% end %>
                <%= if @skills == [] do %>
                  <tr>
                    <td colspan="3" class="text-center opacity-50">No skills found</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp load_data(socket) do
    categories = GiuliaClient.fetch_categories()
    skills = GiuliaClient.fetch_skills()
    socket |> assign(:categories, categories) |> assign(:skills, skills)
  end

  defp category_badge("knowledge"), do: "badge-primary"
  defp category_badge("runtime"), do: "badge-warning"
  defp category_badge("intelligence"), do: "badge-accent"
  defp category_badge("index"), do: "badge-info"
  defp category_badge("monitor"), do: "badge-secondary"
  defp category_badge("search"), do: "badge-success"
  defp category_badge(_), do: "badge-ghost"
end
