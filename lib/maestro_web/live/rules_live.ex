defmodule MaestroWeb.RulesLive do
  @moduledoc "Curation UI for `Maestro.Ops.Rule`."
  use MaestroWeb, :live_view
  use Cinder.UrlSync

  alias Maestro.Ops.Rule.Facade, as: Rules
  import MaestroWeb.Components.RulesStatsComponent
  import MaestroWeb.Components.RulesCurationTable

  @impl true
  def mount(_params, _session, socket) do
    {quality_summary, quality_by_id} = Rules.quality_audit()
    {deps_info, skills} = Rules.coverage_stats()

    {:ok,
     socket
     |> assign(:page_title, "Rules")
     |> assign(:query, Rules.default_query())
     |> assign(:source_options, Rules.source_options())
     |> assign(:status_options, Rules.status_options())
     |> assign(:category_options, Rules.category_options())
     |> assign(:bundle_options, Rules.bundle_options())
     |> assign(:deps_info, deps_info)
     |> assign(:skills, skills)
     |> assign(:quality_summary, quality_summary)
     |> assign(:quality_by_id, quality_by_id)
     |> assign(:bundle_stats, Rules.bundle_stats())
     |> assign(:status_totals, Rules.status_totals())
     |> assign(:category_counts, Rules.category_counts())
     |> assign(:tag_counts, Rules.tag_cloud())
     |> assign(:active_category, nil)
     |> assign(:active_tag, nil)
     |> assign(:selected_ids, MapSet.new())
     |> assign(:show_stats, false)
     |> assign(:source_type_options, Rules.source_type_options())}
  end

  @impl true
  def handle_params(params, uri, socket) do
    socket = Cinder.UrlSync.handle_params(params, uri, socket)
    filters = Rules.extract_cinder_filters(params)
    {:noreply, assign(socket, :tag_counts, Rules.tag_cloud(filters))}
  end

  @impl true
  def handle_event("approve", %{"id" => id}, socket) do
    case Rules.approve_rule(id) do
      :ok ->
        {:noreply, socket |> refresh_counts() |> refresh_table() |> put_flash(:info, "Rule approved")}

      {:error, msg} ->
        {:noreply, put_flash(socket, :error, msg)}
    end
  end

  def handle_event("retire", %{"id" => id}, socket) do
    Rules.retire_rule(id)
    {:noreply, socket |> refresh_counts() |> refresh_table() |> put_flash(:info, "Rule retired")}
  end

  def handle_event("mark_linter", %{"id" => id}, socket) do
    Rules.mark_linter(id)
    {:noreply, socket |> refresh_table() |> put_flash(:info, "Marked as linter rule")}
  end

  def handle_event("mark_anti_pattern", %{"id" => id}, socket) do
    Rules.mark_anti_pattern(id)
    {:noreply, socket |> refresh_counts() |> refresh_table() |> put_flash(:info, "Marked as anti-pattern")}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    Rules.destroy_rule(id)
    {:noreply, socket |> refresh_table() |> put_flash(:info, "Rule deleted")}
  end

  def handle_event("save_notes", %{"rule_id" => id, "notes" => notes}, socket) do
    Rules.update_rule(id, %{notes: notes})
    {:noreply, socket}
  end

  def handle_event("discuss", %{"id" => id}, socket) do
    case Rules.discuss_rule(id) do
      {:ok, task} ->
        {:noreply, put_flash(socket, :info, "Discussion task ##{task.id} created")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create discussion task")}
    end
  end

  def handle_event("export_bundles", _params, socket) do
    case Rules.export_bundles() do
      :ok -> {:noreply, put_flash(socket, :info, "Bundles exported")}
      {:error, output} -> {:noreply, put_flash(socket, :error, "Export failed: #{output}")}
    end
  end

  def handle_event("reprioritize", _params, socket) do
    {updated, _skipped} = Rules.auto_prioritize()

    {:noreply,
     socket
     |> assign(:bundle_stats, Rules.bundle_stats())
     |> refresh_table()
     |> put_flash(:info, "Reprioritized #{updated} rules")}
  end

  def handle_event("filter_tag", %{"tag" => tag}, socket) do
    {query, active} =
      if tag == socket.assigns.active_tag,
        do: {Rules.sorted_query(), nil},
        else: {Rules.query_by_tag(tag), tag}

    {:noreply,
     socket
     |> assign(:query, query)
     |> assign(:active_tag, active)
     |> assign(:active_category, nil)
     |> refresh_table()}
  end

  def handle_event("filter_category", %{"category" => category}, socket) do
    {query, active} =
      if category == socket.assigns.active_category,
        do: {Rules.sorted_query(), nil},
        else: {Rules.query_by_category(category), category}

    {:noreply,
     socket
     |> assign(:query, query)
     |> assign(:active_category, active)
     |> assign(:selected_ids, MapSet.new())
     |> refresh_table()}
  end

  def handle_event("toggle_select", %{"id" => id}, socket) do
    selected =
      if MapSet.member?(socket.assigns.selected_ids, id),
        do: MapSet.delete(socket.assigns.selected_ids, id),
        else: MapSet.put(socket.assigns.selected_ids, id)

    {:noreply, assign(socket, :selected_ids, selected)}
  end

  def handle_event("bulk_approve", _params, socket) do
    count = Rules.bulk_approve(socket.assigns.selected_ids)

    {:noreply,
     socket
     |> assign(:selected_ids, MapSet.new())
     |> refresh_counts()
     |> refresh_table()
     |> put_flash(:info, "Approved #{count} rules")}
  end

  def handle_event("bulk_retire", _params, socket) do
    count = Rules.bulk_retire(socket.assigns.selected_ids)

    {:noreply,
     socket
     |> assign(:selected_ids, MapSet.new())
     |> refresh_counts()
     |> refresh_table()
     |> put_flash(:info, "Retired #{count} rules")}
  end

  def handle_event("filter_source", %{"source" => source}, socket) do
    {:noreply, refresh_table(assign(socket, :query, Rules.query_by_source(source)))}
  end

  def handle_event("filter_source_status", %{"source" => source, "status" => status}, socket) do
    query = Rules.query_by_source_status(source, String.to_existing_atom(status))
    {:noreply, refresh_table(assign(socket, :query, query))}
  end

  def handle_event("toggle_stats", _params, socket) do
    {:noreply, assign(socket, :show_stats, !socket.assigns.show_stats)}
  end

  @impl true
  def handle_info({:selection_changed, _selection}, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="page-section">
        <div class="page-header">
          <div>
            <h1>Rules</h1>
            <p class="description">
              {Enum.sum(Enum.map(@status_totals, fn {_s, c} -> c end))} total
              · {status_count(@status_totals, "approved")} approved
              · {status_count(@status_totals, "proposed")} proposed
            </p>
          </div>
          <div class="join">
            <a href="/rules/new" class="btn btn-sm btn-success">
              <.icon name="hero-plus" class="w-4 h-4" /> New Rule
            </a>
            <button phx-click="export_bundles" class="btn btn-sm btn-primary btn-outline">
              <.icon name="hero-arrow-down-tray" class="w-4 h-4" /> Export
            </button>
            <button phx-click="reprioritize" class="btn btn-sm btn-ghost">
              <.icon name="hero-arrow-path" class="w-4 h-4" /> Reprioritize
            </button>
            <button phx-click="toggle_stats" class="btn btn-ghost btn-sm">
              <.icon name="hero-chart-bar" class="w-4 h-4" />
              {if @show_stats, do: "Hide", else: "Stats"}
            </button>
          </div>
        </div>

        <.rules_stats
          :if={@show_stats}
          bundle_stats={@bundle_stats}
          quality_summary={@quality_summary}
          deps_info={@deps_info}
        />

        <.filter_chips tag_counts={@tag_counts} active_tag={@active_tag} />
        <.category_chips category_counts={@category_counts} active_category={@active_category} />

        <.rules_table
          query={@query}
          url_state={@url_state}
          status_options={@status_options}
          category_options={@category_options}
          bundle_options={@bundle_options}
          source_type_options={@source_type_options}
        />

      </div>
    </Layouts.app>
    """
  end

  # -- Minimal view helpers --

  defp refresh_table(socket), do: Cinder.Refresh.refresh_table(socket, "rules-table")

  defp refresh_counts(socket) do
    socket
    |> assign(:category_counts, Rules.category_counts())
    |> assign(:status_totals, Rules.status_totals())
  end

  defp status_count(totals, status) do
    case Enum.find(totals, fn {s, _} -> s == status end) do
      {_, count} -> count
      nil -> 0
    end
  end

  attr :tag_counts, :list, required: true
  attr :active_tag, :string, default: nil

  defp filter_chips(assigns) do
    ~H"""
    <div class="filter-chips">
      <%= for {tag, count} <- @tag_counts do %>
        <button
          phx-click="filter_tag"
          phx-value-tag={tag}
          class={["badge cursor-pointer gap-1", if(@active_tag == tag, do: "badge-primary", else: "badge-outline badge-sm")]}
        >
          {tag} <span class="opacity-60">{count}</span>
        </button>
      <% end %>
    </div>
    """
  end

  attr :category_counts, :list, required: true
  attr :active_category, :string, default: nil

  defp category_chips(assigns) do
    ~H"""
    <div class="filter-chips">
      <%= for {cat, count} <- @category_counts do %>
        <button
          phx-click="filter_category"
          phx-value-category={cat}
          class={["badge badge-lg cursor-pointer gap-1", if(@active_category == cat, do: "badge-primary", else: "badge-outline")]}
        >
          {cat} <span class="badge badge-sm badge-ghost">{count}</span>
        </button>
      <% end %>
    </div>
    """
  end
end
