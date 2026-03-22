defmodule MaestroWeb.RulesLive do
  use MaestroWeb, :live_view

  alias Maestro.Ops.Rule
  alias Maestro.Ops.Rules.{Coverage, Quality}
  import Ash.Query

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

  defp status_badge_class(:proposed), do: "badge-warning"
  defp status_badge_class(:approved), do: "badge-success"
  defp status_badge_class(:retired), do: "badge-ghost"
  defp status_badge_class(:linter), do: "badge-info"
  defp status_badge_class(_), do: ""

  defp severity_badge_class(:must), do: "badge-error"
  defp severity_badge_class(:should), do: "badge-warning"
  defp severity_badge_class(:prefer), do: "badge-info"
  defp severity_badge_class(_), do: ""

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:status_options, @status_options)
      |> assign(:category_options, @category_options)

    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="max-w-7xl mx-auto px-8 py-6">
        <div class="flex items-center justify-between mb-4">
          <h1 class="text-3xl font-bold">Rules</h1>
          <button phx-click="toggle_stats" class="btn btn-ghost btn-sm">
            <.icon name="hero-chart-bar" class="w-4 h-4" />
            {if @show_stats, do: "Hide", else: "Show"} Stats
          </button>
        </div>

        <%!-- Coverage Dashboard --%>
        <%= if @show_stats do %>
          <div class="card bg-base-200 mb-4">
            <div class="card-body p-4">
              <h3 class="font-semibold text-sm mb-2">Curation Coverage</h3>
              <div class="overflow-x-auto">
                <table class="table table-xs">
                  <thead>
                    <tr>
                      <th>Source</th>
                      <th class="text-center">Ver</th>
                      <th class="text-center">Rules</th>
                      <th class="text-center">Coverage</th>
                      <th class="text-center text-success">A</th>
                      <th class="text-center text-info">L</th>
                      <th class="text-center text-base-content/40">R</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for d <- @deps_info do %>
                      <tr>
                        <td class="font-mono text-xs">{d.dep}</td>
                        <td class="text-center text-xs text-base-content/50">{d.version}</td>
                        <td class="text-center">{d.source_count}</td>
                        <td class="text-center">
                          <progress
                            class={[
                              "progress w-12",
                              cond do
                                d.coverage_pct >= 80 -> "progress-success"
                                d.coverage_pct >= 40 -> "progress-warning"
                                true -> "progress-error"
                              end
                            ]}
                            value={d.coverage_pct}
                            max="100"
                          />
                          <span class="text-xs ml-1">{d.coverage_pct}%</span>
                        </td>
                        <td class="text-center text-success">{d.approved}</td>
                        <td class="text-center text-info">{d.linter}</td>
                        <td class="text-center text-base-content/40">{d.retired}</td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
              <%= if @skills != [] do %>
                <div class="flex gap-2 mt-2">
                  <%= for skill <- @skills do %>
                    <div class="badge badge-outline badge-sm gap-1">
                      <span class="font-semibold">{skill.name}</span>
                      <span class="text-base-content/40">{length(skill.library_names)} libs</span>
                    </div>
                  <% end %>
                </div>
              <% end %>

              <%!-- Quality Gate --%>
              <div class="quality-gate-summary">
                <h3>Quality Gate</h3>
                <div class="quality-gate-stats">
                  <span class="badge badge-success gap-1">
                    Pass <span class="badge badge-success badge-xs">{@quality_summary.pass}</span>
                  </span>
                  <span class="badge badge-error gap-1">
                    Fail <span class="badge badge-error badge-xs">{@quality_summary.fail}</span>
                  </span>
                  <span class="badge badge-outline gap-1">
                    {@quality_summary.pass_rate}% pass rate
                  </span>
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
            field="category"
            label="Category"
            sort
            filter={[type: :select, options: @category_options]}
          >
            {rule.category}
          </:col>

          <:col
            :let={rule}
            field="source_project_slug"
            label="Source"
            sort
            filter={[type: :select, options: @source_options]}
          >
            <span class="text-xs">{rule.source_project_slug}</span>
          </:col>

          <:col :let={rule} field="content" label="Content" filter>
            <p class="text-sm whitespace-pre-wrap max-w-xl truncate">
              {String.slice(rule.content, 0, 200)}
            </p>
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
