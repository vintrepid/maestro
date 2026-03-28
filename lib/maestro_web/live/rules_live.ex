defmodule MaestroWeb.RulesLive do
  @moduledoc """
  Curation UI for Maestro's rules system. This is THE tool for managing agent rules.

  ## Curation Workflow

  Rules flow: ingested (from deps/agents) → proposed → approved/retired.
  This page is where the human curator reviews proposed rules and decides
  which to approve (agents will follow) or retire (agents will ignore).

  ## Features

  - **Category chips** — clickable category counts at the top, filter to one category
  - **Bulk actions** — select multiple rules, approve/retire in batch
  - **Status filter** — defaults to showing proposed rules (the curation queue)
  - **Priority sort** — highest priority rules shown first
  - **Quality gate** — rules must pass quality checks before approval
  - **Bundle stats** — see how many rules per bundle (universal/ui/model/maestro)

  ## Key Events

  - `approve` / `retire` / `delete` — single rule actions
  - `bulk_approve` / `bulk_retire` — batch actions on selected rules
  - `filter_category` — filter table to a single category
  - `filter_status` — filter by proposed/approved/retired/linter
  - `toggle_select` / `select_all` — selection for bulk actions
  - `export_bundles` — runs `mix maestro.rules.export`
  - `reprioritize` — auto-assigns priority scores

  ## After Curation

  Run `mix maestro.rules.export` (or click Export Bundles) to write:
  - rules.json — compact rules for agent startup
  - AGENTS.md — human-readable rules reference
  - RULES.md — full rules documentation
  """
  use MaestroWeb, :live_view

  alias Maestro.Ops.Rule
  alias Maestro.Ops.Rules.{Coverage, Quality}
  import Ash.Query
  import Ecto.Query, only: [from: 2]

  @status_options [
    {"Proposed", "proposed"},
    {"Approved", "approved"},
    {"Linter", "linter"},
    {"Retired", "retired"}
  ]

  @category_options [
    {"Architecture", "architecture"},
    {"Ash", "ash"},
    {"Components", "components"},
    {"CSS", "css"},
    {"Elixir", "elixir"},
    {"Forms", "forms"},
    {"HEEx", "heex"},
    {"LiveView", "liveview"},
    {"PubSub", "pubsub"},
    {"Routing", "routing"},
    {"Security", "security"},
    {"Testing", "testing"}
  ]

  @bundle_options [
    {"Universal", "universal"},
    {"UI", "ui"},
    {"Model", "model"},
    {"DevOps", "devops"},
    {"Maestro", "maestro"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    source_options = build_source_options()
    category_counts = load_category_counts()
    tag_counts = load_tag_counts()

    query =
      Rule
      |> sort(priority: :desc, category: :asc)

    quality_results = Rule.approved!() |> Quality.audit_rules()
    quality_summary = Quality.summarize(quality_results)
    quality_by_id = Map.new(quality_results, &{&1.id, &1})

    {:ok,
     socket
     |> assign(:page_title, "Rules")
     |> assign(:query, query)
     |> assign(:source_options, source_options)
     |> assign(:deps_info, Coverage.by_library())
     |> assign(:skills, Coverage.skills())
     |> assign(:quality_summary, quality_summary)
     |> assign(:quality_by_id, quality_by_id)
     |> assign(:bundle_stats, load_bundle_stats())
     |> assign(:status_totals, load_status_totals())
     |> assign(:category_counts, category_counts)
     |> assign(:tag_counts, tag_counts)
     |> assign(:active_category, nil)
     |> assign(:active_tag, nil)
     |> assign(:selected_ids, MapSet.new())
     |> assign(:show_stats, false)}
  end

  @impl true
  def handle_event("approve", %{"id" => id}, socket) do
    rule = Rule.by_id!(id)

    if Quality.passes_quality?(rule) do
      Rule.approve(rule)

      {:noreply,
       socket
       |> assign(:category_counts, load_category_counts())
       |> assign(:status_totals, load_status_totals())
       |> refresh_table()
       |> put_flash(:info, "Rule approved")}
    else
      {:noreply, put_flash(socket, :error, "Rule fails quality checks — fix content before approving")}
    end
  end

  def handle_event("retire", %{"id" => id}, socket) do
    Rule.by_id!(id) |> Rule.retire(%{retired_reason: "Retired from UI"})

    {:noreply,
     socket
     |> assign(:category_counts, load_category_counts())
     |> assign(:status_totals, load_status_totals())
     |> refresh_table()
     |> put_flash(:info, "Rule retired")}
  end

  def handle_event("mark_linter", %{"id" => id}, socket) do
    Rule.by_id!(id) |> Rule.mark_linter()
    {:noreply, socket |> refresh_table() |> put_flash(:info, "Marked as linter rule")}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    Rule.by_id!(id) |> Rule.destroy()
    {:noreply, socket |> refresh_table() |> put_flash(:info, "Rule deleted")}
  end

  def handle_event("save_notes", %{"rule_id" => id, "notes" => notes}, socket) do
    Rule.by_id!(id) |> Rule.update(%{notes: notes})
    {:noreply, socket}
  end

  def handle_event("export_bundles", _params, socket) do
    case System.cmd("mix", ["maestro.rules.export"], stderr_to_stdout: true) do
      {_output, 0} ->
        {:noreply, put_flash(socket, :info, "Bundles exported successfully")}

      {output, _} ->
        {:noreply, put_flash(socket, :error, "Export failed: #{String.slice(output, 0, 200)}")}
    end
  end

  def handle_event("reprioritize", _params, socket) do
    {updated, _skipped} = Maestro.Ops.Rules.Prioritizer.auto_assign_all()

    {:noreply,
     socket
     |> assign(:bundle_stats, load_bundle_stats())
     |> refresh_table()
     |> put_flash(:info, "Reprioritized #{updated} rules")}
  end

  def handle_event("filter_tag", %{"tag" => tag}, socket) do
    query =
      if tag == socket.assigns.active_tag do
        Rule |> sort(priority: :desc)
      else
        Rule
        |> filter(fragment("? @> ARRAY[?]::text[]", tags, ^tag))
        |> sort(priority: :desc)
      end

    active = if tag == socket.assigns.active_tag, do: nil, else: tag

    {:noreply,
     socket
     |> assign(:query, query)
     |> assign(:active_tag, active)
     |> assign(:active_category, nil)
     |> refresh_table()}
  end

  def handle_event("filter_category", %{"category" => category}, socket) do
    query =
      if category == socket.assigns.active_category do
        Rule |> sort(priority: :desc)
      else
        Rule |> filter(category == ^category) |> sort(priority: :desc)
      end

    active = if category == socket.assigns.active_category, do: nil, else: category

    {:noreply,
     socket
     |> assign(:query, query)
     |> assign(:active_category, active)
     |> assign(:selected_ids, MapSet.new())
     |> refresh_table()}
  end

  def handle_event("toggle_select", %{"id" => id}, socket) do
    selected =
      if MapSet.member?(socket.assigns.selected_ids, id) do
        MapSet.delete(socket.assigns.selected_ids, id)
      else
        MapSet.put(socket.assigns.selected_ids, id)
      end

    {:noreply, assign(socket, :selected_ids, selected)}
  end

  def handle_event("bulk_approve", _params, socket) do
    count =
      socket.assigns.selected_ids
      |> Enum.reduce(0, fn id, acc ->
        rule = Rule.by_id!(id)
        case Rule.approve(rule) do
          {:ok, _} -> acc + 1
          _ -> acc
        end
      end)

    {:noreply,
     socket
     |> assign(:selected_ids, MapSet.new())
     |> assign(:category_counts, load_category_counts())
     |> assign(:status_totals, load_status_totals())
     |> refresh_table()
     |> put_flash(:info, "Approved #{count} rules")}
  end

  def handle_event("bulk_retire", _params, socket) do
    count =
      socket.assigns.selected_ids
      |> Enum.reduce(0, fn id, acc ->
        rule = Rule.by_id!(id)
        case Rule.retire(rule, %{retired_reason: "Bulk retired from curation UI"}) do
          {:ok, _} -> acc + 1
          _ -> acc
        end
      end)

    {:noreply,
     socket
     |> assign(:selected_ids, MapSet.new())
     |> assign(:category_counts, load_category_counts())
     |> assign(:status_totals, load_status_totals())
     |> refresh_table()
     |> put_flash(:info, "Retired #{count} rules")}
  end

  def handle_event("filter_source", %{"source" => source}, socket) do
    query = Rule |> filter(source_project_slug == ^source) |> sort(updated_at: :desc)
    {:noreply, assign(socket, :query, query) |> refresh_table()}
  end

  def handle_event("filter_source_status", %{"source" => source, "status" => status}, socket) do
    status_atom = String.to_existing_atom(status)

    query =
      Rule
      |> filter(source_project_slug == ^source and status == ^status_atom)
      |> sort(updated_at: :desc)

    {:noreply, assign(socket, :query, query) |> refresh_table()}
  end

  def handle_event("toggle_stats", _params, socket) do
    {:noreply, assign(socket, :show_stats, !socket.assigns.show_stats)}
  end

  defp refresh_table(socket) do
    Cinder.Refresh.refresh_table(socket, "rules-table")
  end

  defp build_source_options do
    Rule.read!()
    |> Enum.map(& &1.source_project_slug)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(&{&1, &1})
  end

  defp load_bundle_stats do
    Maestro.Repo.all(
      from r in "rules",
        where: r.status == "approved",
        group_by: r.bundle,
        select: {r.bundle, count(r.id)},
        order_by: [desc: count(r.id)]
    )
  end

  defp load_tag_counts do
    case Ecto.Adapters.SQL.query(Maestro.Repo,
      "SELECT unnest(tags) as tag, count(*) as cnt FROM rules WHERE status = 'proposed' GROUP BY tag ORDER BY cnt DESC"
    ) do
      {:ok, %{rows: rows}} -> Enum.map(rows, fn [tag, cnt] -> {tag, cnt} end)
      _ -> []
    end
  end

  defp load_category_counts do
    Maestro.Repo.all(
      from r in "rules",
        where: r.status == "proposed",
        group_by: r.category,
        select: {r.category, count(r.id)},
        order_by: [desc: count(r.id)]
    )
  end

  defp load_status_totals do
    Maestro.Repo.all(
      from r in "rules",
        group_by: r.status,
        select: {r.status, count(r.id)}
    )
  end

  defp status_count(totals, status) do
    case Enum.find(totals, fn {s, _} -> s == status end) do
      {_, count} -> count
      nil -> 0
    end
  end

  defp max_bundle_count(stats) do
    case stats do
      [] -> 1
      stats -> stats |> Enum.map(fn {_, c} -> c end) |> Enum.max()
    end
  end

  defp status_badge_class(:proposed), do: "badge-warning"
  defp status_badge_class(:approved), do: "badge-success"
  defp status_badge_class(:retired), do: "badge-ghost"
  defp status_badge_class(:linter), do: "badge-info"
  defp status_badge_class(_), do: ""

  defp severity_badge_class(:must), do: "badge-error"
  defp severity_badge_class(:should), do: "badge-warning"
  defp severity_badge_class(:prefer), do: "badge-info"
  defp severity_badge_class(_), do: ""

  defp bundle_badge_class("universal"), do: "badge-primary"
  defp bundle_badge_class(:universal), do: "badge-primary"
  defp bundle_badge_class("ui"), do: "badge-secondary"
  defp bundle_badge_class(:ui), do: "badge-secondary"
  defp bundle_badge_class("model"), do: "badge-accent"
  defp bundle_badge_class(:model), do: "badge-accent"
  defp bundle_badge_class("devops"), do: "badge-info"
  defp bundle_badge_class(:devops), do: "badge-info"
  defp bundle_badge_class("maestro"), do: "badge-warning"
  defp bundle_badge_class(:maestro), do: "badge-warning"
  defp bundle_badge_class(_), do: "badge-ghost"

  defp bundle_progress_class("universal"), do: "progress-primary"
  defp bundle_progress_class("model"), do: "progress-accent"
  defp bundle_progress_class("ui"), do: "progress-secondary"
  defp bundle_progress_class("devops"), do: "progress-info"
  defp bundle_progress_class("maestro"), do: "progress-warning"
  defp bundle_progress_class(_), do: ""

  defp priority_color(p) when p >= 80, do: "text-error font-semibold"
  defp priority_color(p) when p >= 60, do: "text-warning"
  defp priority_color(_), do: "text-base-content/50"

  defp coverage_color(pct) when pct >= 80, do: "text-success"
  defp coverage_color(pct) when pct >= 40, do: "text-warning"
  defp coverage_color(_), do: "text-error"

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:status_options, @status_options)
      |> assign(:category_options, @category_options)
      |> assign(:bundle_options, @bundle_options)

    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="max-w-7xl mx-auto px-8 py-6">
        <div class="flex items-center justify-between mb-4">
          <div>
            <h1 class="text-3xl font-bold">Rules</h1>
            <p class="text-sm opacity-60 mt-1">
              {Enum.sum(Enum.map(@status_totals, fn {_s, c} -> c end))} total
              · {status_count(@status_totals, "approved")} approved
              · {status_count(@status_totals, "proposed")} proposed
            </p>
          </div>
          <div class="flex gap-2">
            <button phx-click="export_bundles" class="btn btn-sm btn-primary btn-outline">
              <.icon name="hero-arrow-down-tray" class="w-4 h-4" />
              Export Bundles
            </button>
            <button phx-click="reprioritize" class="btn btn-sm btn-ghost">
              <.icon name="hero-arrow-path" class="w-4 h-4" />
              Reprioritize
            </button>
            <button phx-click="toggle_stats" class="btn btn-ghost btn-sm">
              <.icon name="hero-chart-bar" class="w-4 h-4" />
              {if @show_stats, do: "Hide", else: "Show"} Stats
            </button>
          </div>
        </div>

        <%!-- Stats Dashboard --%>
        <%= if @show_stats do %>
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 mb-4">
            <%!-- Bundle Distribution --%>
            <div class="card bg-base-200">
              <div class="card-body p-4">
                <h3 class="font-semibold text-sm mb-3">Bundle Distribution</h3>
                <div class="space-y-2">
                  <%= for {bundle, count} <- @bundle_stats do %>
                    <div class="flex items-center gap-3">
                      <span class={["badge badge-sm w-20 justify-center", bundle_badge_class(bundle)]}>{bundle}</span>
                      <progress
                        class={["progress flex-1", bundle_progress_class(bundle)]}
                        value={count}
                        max={max_bundle_count(@bundle_stats)}
                      />
                      <span class="text-sm font-mono w-8 text-right">{count}</span>
                    </div>
                  <% end %>
                </div>
                <p class="text-xs opacity-40 mt-2">
                  Agents read <code>rules.json</code> (universal) + specialized bundle.
                  Generated by <code>mix maestro.rules.export</code>.
                </p>
              </div>
            </div>

            <%!-- Quality + Coverage --%>
            <div class="card bg-base-200">
              <div class="card-body p-4">
                <h3 class="font-semibold text-sm mb-3">Quality + Coverage</h3>
                <div class="flex gap-3 mb-3">
                  <span class="badge badge-success gap-1">
                    Pass <span class="font-mono">{@quality_summary.pass}</span>
                  </span>
                  <span class="badge badge-error gap-1">
                    Fail <span class="font-mono">{@quality_summary.fail}</span>
                  </span>
                  <span class="badge badge-outline gap-1">
                    {@quality_summary.pass_rate}% pass rate
                  </span>
                </div>
                <div class="overflow-x-auto max-h-48">
                  <table class="table table-xs">
                    <thead>
                      <tr>
                        <th>Source</th>
                        <th class="text-center">Cov</th>
                        <th class="text-center text-success">A</th>
                        <th class="text-center text-warning">P</th>
                        <th class="text-center text-info">L</th>
                        <th class="text-center text-base-content/40">R</th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for d <- @deps_info do %>
                        <tr>
                          <td
                            class="font-mono text-xs cursor-pointer hover:underline"
                            phx-click="filter_source"
                            phx-value-source={d.dep}
                          >
                            {d.dep}
                          </td>
                          <td class="text-center">
                            <span class={["text-xs font-mono", coverage_color(d.coverage_pct)]}>{d.coverage_pct}%</span>
                          </td>
                          <td class="text-center">
                            <span class="text-success cursor-pointer hover:underline"
                              phx-click="filter_source_status" phx-value-source={d.dep} phx-value-status="approved">{d.approved}</span>
                          </td>
                          <td class="text-center">
                            <span class={["cursor-pointer hover:underline", if(d.proposed > 0, do: "text-warning font-semibold", else: "text-base-content/40")]}
                              phx-click="filter_source_status" phx-value-source={d.dep} phx-value-status="proposed">{d.proposed}</span>
                          </td>
                          <td class="text-center">
                            <span class="text-info cursor-pointer hover:underline"
                              phx-click="filter_source_status" phx-value-source={d.dep} phx-value-status="linter">{d.linter}</span>
                          </td>
                          <td class="text-center">
                            <span class="text-base-content/40 cursor-pointer hover:underline"
                              phx-click="filter_source_status" phx-value-source={d.dep} phx-value-status="retired">{d.retired}</span>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          </div>
        <% end %>

        <%!-- Tag Chips --%>
        <div class="flex flex-wrap gap-2 mb-2">
          <%= for {tag, count} <- @tag_counts do %>
            <button
              phx-click="filter_tag"
              phx-value-tag={tag}
              class={[
                "badge cursor-pointer gap-1 transition-all",
                if(@active_tag == tag, do: "badge-primary", else: "badge-outline badge-sm hover:badge-primary/50")
              ]}
            >
              {tag}
              <span class="text-xs opacity-60">{count}</span>
            </button>
          <% end %>
        </div>

        <%!-- Category Chips --%>
        <div class="flex flex-wrap gap-2 mb-4">
          <%= for {cat, count} <- @category_counts do %>
            <button
              phx-click="filter_category"
              phx-value-category={cat}
              class={[
                "badge badge-lg cursor-pointer gap-1 transition-all",
                if(@active_category == cat, do: "badge-primary", else: "badge-outline hover:badge-primary/50")
              ]}
            >
              {cat}
              <span class="badge badge-sm badge-ghost">{count}</span>
            </button>
          <% end %>
        </div>

        <%!-- Cinder Table --%>
        <Cinder.collection
          id="rules-table"
          query={@query}
          page_size={50}
          theme="daisy_ui"
          selectable
          on_selection_change={:selection_changed}
        >
          <:bulk_action label="Approve" action={:approve} class="btn-success" />
          <:bulk_action label="Retire" action={:retire} class="btn-warning" />
          <:col
            :let={rule}
            field="status"
            label="Status"
            sort
            filter={[type: :select, options: @status_options]}
          >
            <span class={["badge badge-sm", status_badge_class(rule.status)]}>{rule.status}</span>
          </:col>

          <:col
            :let={rule}
            field="severity"
            label="Sev"
            sort
            filter={[
              type: :select,
              options: [{"Must", "must"}, {"Should", "should"}, {"Prefer", "prefer"}]
            ]}
          >
            <span class={["badge badge-sm badge-outline", severity_badge_class(rule.severity)]}>
              {rule.severity}
            </span>
          </:col>

          <:col
            :let={rule}
            field="bundle"
            label="Bundle"
            sort
            filter={[type: :select, options: @bundle_options]}
          >
            <span class={["badge badge-sm", bundle_badge_class(rule.bundle)]}>{rule.bundle}</span>
          </:col>

          <:col
            :let={rule}
            field="priority"
            label="Pri"
            sort
          >
            <span class={["font-mono text-xs", priority_color(rule.priority)]}>{rule.priority}</span>
          </:col>

          <:col
            :let={rule}
            field="category"
            label="Category"
            sort
            filter={[type: :select, options: @category_options]}
          >
            {rule.category}
          </:col>

          <:col :let={rule} field="content" label="Content" filter>
            <p class="text-sm whitespace-pre-wrap max-w-xl truncate">
              {String.slice(rule.content, 0, 200)}
            </p>
          </:col>

          <:col :let={rule} field="notes" label="Notes">
            <form phx-change="save_notes">
              <input type="hidden" name="rule_id" value={rule.id} />
              <textarea
                name="notes"
                placeholder="Add note..."
                rows="2"
                class="textarea textarea-xs textarea-bordered w-40 leading-tight"
              >{rule.notes}</textarea>
            </form>
          </:col>

          <:col :let={rule} field="id" label="">
            <div class="flex gap-1">
              <%= if rule.status == :proposed do %>
                <button
                  phx-click="approve"
                  phx-value-id={rule.id}
                  class="btn btn-xs btn-success btn-outline"
                >
                  Approve
                </button>
                <button
                  phx-click="mark_linter"
                  phx-value-id={rule.id}
                  class="btn btn-xs btn-info btn-outline"
                >
                  Linter
                </button>
              <% end %>
              <%= if rule.status not in [:retired, :linter] do %>
                <button
                  phx-click="retire"
                  phx-value-id={rule.id}
                  class="btn btn-xs btn-ghost text-warning"
                >
                  Retire
                </button>
              <% end %>
              <button
                phx-click="delete"
                phx-value-id={rule.id}
                class="btn btn-xs btn-ghost text-error"
                data-confirm="Delete?"
              >
                <.icon name="hero-trash" class="w-3 h-3" />
              </button>
            </div>
          </:col>
        </Cinder.collection>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_info({:selection_changed, _selection}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_params(socket, socket.assigns.live_action, params)}
  end

  defp apply_params(socket, _action, _params),
    do: socket
end
