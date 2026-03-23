defmodule MaestroWeb.RulesLive do
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

    query =
      Rule
      |> sort(updated_at: :desc)

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
     |> assign(:show_stats, true)}
  end

  @impl true
  def handle_event("approve", %{"id" => id}, socket) do
    rule = Rule.by_id!(id)

    if Quality.passes_quality?(rule) do
      Rule.approve(rule)
      {:noreply, socket |> refresh_table() |> put_flash(:info, "Rule approved")}
    else
      {:noreply, put_flash(socket, :error, "Rule fails quality checks — fix content before approving")}
    end
  end

  def handle_event("retire", %{"id" => id}, socket) do
    Rule.by_id!(id) |> Rule.retire(%{retired_reason: "Retired from UI"})
    {:noreply, socket |> refresh_table() |> put_flash(:info, "Rule retired")}
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

        <%!-- Cinder Table --%>
        <Cinder.collection
          id="rules-table"
          query={@query}
          page_size={50}
          theme="daisy_ui"
        >
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
            <form phx-change="save_notes" phx-debounce="500">
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
  def handle_params(params, _uri, socket) do
    {:noreply, apply_params(socket, socket.assigns.live_action, params)}
  end

  defp apply_params(socket, _action, _params),
    do: socket
end
