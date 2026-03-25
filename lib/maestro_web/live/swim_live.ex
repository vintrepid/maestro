defmodule MaestroWeb.SwimLive do
  @moduledoc """
  Swim entries page with Cinder table.

  Displays all swim entries with sortable/filterable columns.
  Supports importing SD3 files via the import button.

  ## Route

    `/swim` — `:index` action

  ## Events

    - `import_sd3` — Imports the default SD3 file
  """

  use MaestroWeb, :live_view

  import Ecto.Query
  alias Maestro.Swim.Entry

  @impl true
  def mount(_params, _session, socket) do
    query = Entry |> Ash.Query.sort(event_number: :asc)

    entry_count = Maestro.Repo.one(from e in "swim_entries", select: count(e.id))

    {:ok,
     socket
     |> assign(:page_title, "Swim Entries")
     |> assign(:query, query)
     |> assign(:entry_count, entry_count)}
  end

  @impl true
  def handle_event("import_sd3", _params, socket) do
    path = "/Users/vince/dev/kj & the melvins/OARI-Entries-Folsom VS Oak Ridge-23Mar2026-2306/OARI-Entries-Folsom VS Oak Ridge-23Mar2026-2306.sd3"

    case Maestro.Swim.Sd3Parser.import_file!(path) do
      {:ok, %{meet: meet, entries: entries}} ->
        entry_count = length(entries)

        {:noreply,
         socket
         |> assign(:entry_count, entry_count)
         |> assign(:query, Entry |> Ash.Query.sort(event_number: :asc))
         |> put_flash(:info, "Imported #{entry_count} entries for #{meet.name}")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Import failed: #{inspect(reason)}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="max-w-7xl mx-auto px-8 py-6">
        <div class="flex items-center justify-between mb-4">
          <div>
            <h1 class="text-3xl font-bold">Swim Entries</h1>
            <p class="text-sm opacity-60 mt-1">{@entry_count} entries</p>
          </div>
          <button phx-click="import_sd3" class="btn btn-sm btn-primary btn-outline">
            <.icon name="hero-arrow-up-tray" class="w-4 h-4" />
            Import SD3
          </button>
        </div>

        <Cinder.collection
          id="swim-entries-table"
          query={@query}
          page_size={50}
          theme="daisy_ui"
        >
          <:col :let={entry} field="event_number" label="Evt#" sort>
            <span class="font-mono">{entry.event_number}</span>
          </:col>

          <:col :let={entry} field="event_name" label="Event" sort filter>
            {entry.event_name}
          </:col>

          <:col :let={entry} field="swimmer_id" label="Swimmer">
            <% swimmer = Maestro.Repo.get(Maestro.Swim.Swimmer, entry.swimmer_id) %>
            <%= if swimmer do %>
              <span class="font-semibold">{swimmer.last_name}</span>, {swimmer.first_name}
              <span class="text-xs opacity-50 ml-1">{swimmer.age}{swimmer.gender}</span>
            <% end %>
          </:col>

          <:col :let={entry} field="seed_time" label="Seed Time" sort>
            <span class={["font-mono", if(entry.seed_time == "NT", do: "opacity-40", else: "")]}>
              {entry.seed_time}
            </span>
          </:col>

          <:col :let={entry} field="stroke" label="Stroke" sort filter>
            {entry.stroke}
          </:col>

          <:col :let={entry} field="distance" label="Dist" sort>
            {entry.distance}
          </:col>

          <:col :let={entry} field="course" label="Course" sort>
            {entry.course}
          </:col>
        </Cinder.collection>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_params(socket, socket.assigns.live_action, params)}
  end

  defp apply_params(socket, _action, _params), do: socket
end
