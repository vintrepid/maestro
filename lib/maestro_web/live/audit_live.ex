defmodule MaestroWeb.AuditLive do
  use MaestroWeb, :live_view

  alias Maestro.Ops.Rule
  alias Maestro.Ops.Rules.{SiteAudit, Fixer}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Site Audit")
     |> assign(:page_results, [])
     |> assign(:summary, nil)
     |> assign(:selected_page, nil)
     |> assign(:running, false)}
  end

  @impl true
  def handle_event("run_audit", _params, socket) do
    if connected?(socket),
      do: Phoenix.PubSub.subscribe(Maestro.PubSub, "resource:updates")

    send(self(), :do_audit)
    {:noreply, assign(socket, :running, true)}
  end

  @impl true
  def handle_info(:do_audit, socket) do
    # Audit against all curated rules (approved + proposed), not just approved.
    # The skip mechanism filters out non-page-checkable rules.
    pages = SiteAudit.discover_pages(MaestroWeb.Router, MaestroWeb)
    all_rules = Rule.read!() |> Enum.filter(&(&1.status in [:approved, :proposed, :linter]))
    page_results = SiteAudit.audit_pages(pages, all_rules)
    summary = SiteAudit.summarize(page_results)

    sorted = Enum.sort_by(page_results, & &1.score)
    checked = summary.total_checks
    skipped = if(sorted != [], do: hd(sorted).skip, else: 0)
    timestamp = Calendar.strftime(DateTime.utc_now(), "%H:%M:%S")

    {:noreply,
     socket
     |> assign(:page_results, sorted)
     |> assign(:summary, summary)
     |> assign(:running, false)
     |> put_flash(:info, "Audit completed at #{timestamp} — #{checked} checks run, #{skipped} rules skipped per page (#{length(all_rules)} total rules)")}
  end

  def handle_event("select_page", %{"path" => path}, socket) do
    selected = Enum.find(socket.assigns.page_results, &(&1.path == path))
    {:noreply, assign(socket, :selected_page, selected)}
  end

  def handle_event("close_detail", _params, socket) do
    {:noreply, assign(socket, :selected_page, nil)}
  end

  def handle_event("fix_all", _params, socket) do
    all_rules = Rule.read!() |> Enum.filter(&(&1.status in [:approved, :proposed, :linter]))
    rules_by_id = Map.new(all_rules, &{&1.id, &1})

    igniter = Igniter.new()

    {updated_igniter, _fixed_count} =
      Enum.reduce(socket.assigns.page_results, {igniter, 0}, fn pr, {ign, count} ->
        fixable =
          Enum.count(pr.findings, fn f ->
            (not f.pass? and rules_by_id[f.rule_id]) && rules_by_id[f.rule_id].fix_type != nil
          end)

        case Fixer.fix_page(ign, pr, rules_by_id) do
          {:ok, new_ign} -> {new_ign, count + fixable}
          _ -> {ign, count}
        end
      end)

    # Write changes to disk
    sources = updated_igniter.rewrite.sources
    changed = Enum.filter(sources, fn {_path, source} -> Rewrite.Source.updated?(source) end)

    for {path, source} <- changed do
      content = Rewrite.Source.get(source, :content)
      File.write!(path, content)
    end

    {:noreply,
     socket
     |> put_flash(:info, "Fixed #{length(changed)} file(s). Re-run audit to see results.")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="page-section">
        <div class="page-header">
          <h1>Site Audit</h1>
          <p class="description">
            Audit every page against approved rules. Click a page to see per-rule findings.
          </p>
        </div>

        <div class="audit-controls">
          <button id="run-audit-btn" phx-click="run_audit" class="btn btn-primary" disabled={@running}>
            <%= if @running do %>
              <span class="loading loading-spinner loading-sm"></span> Running...
            <% else %>
              <.icon name="hero-play" class="w-4 h-4" /> Run Audit
            <% end %>
          </button>

          <%= if @summary && @summary.total_fail > 0 do %>
            <button id="fix-all-btn" phx-click="fix_all" class="btn btn-warning">
              <.icon name="hero-wrench-screwdriver" class="w-4 h-4" /> Fix All
            </button>
          <% end %>
        </div>

        <%= if @summary do %>
          <div class="audit-summary">
            <div class="stats shadow">
              <div class="stat">
                <div class="stat-title">Pages</div>
                <div class="stat-value">{@summary.total_pages}</div>
              </div>
              <div class="stat">
                <div class="stat-title">Avg Score</div>
                <div class="stat-value">{@summary.avg_score}%</div>
              </div>
              <div class="stat">
                <div class="stat-title">Checks Pass</div>
                <div class="stat-value text-success">{@summary.total_pass}</div>
              </div>
              <div class="stat">
                <div class="stat-title">Checks Fail</div>
                <div class="stat-value text-error">{@summary.total_fail}</div>
              </div>
            </div>

            <%= if @summary.failing_by_category != [] do %>
              <div class="audit-breakdown">
                <h3>Failures by Category</h3>
                <div class="audit-check-list">
                  <%= for fc <- @summary.failing_by_category do %>
                    <span class="badge badge-error badge-outline gap-1">
                      {fc.category}
                      <span class="badge badge-error badge-xs">{fc.count}</span>
                    </span>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>

        <%= if @page_results != [] do %>
          <div class="audit-results">
            <table class="table" id="audit-table">
              <thead>
                <tr>
                  <th>Score</th>
                  <th>Page</th>
                  <th>Module</th>
                  <th>Pass</th>
                  <th>Fail</th>
                  <th>Skip</th>
                </tr>
              </thead>
              <tbody>
                <%= for pr <- @page_results do %>
                  <tr
                    class={["audit-page-row", score_row_class(pr.score)]}
                    phx-click="select_page"
                    phx-value-path={pr.path}
                  >
                    <td>
                      <div
                        class={["radial-progress", score_color(pr.score)]}
                        style={"--value:#{pr.score}; --size:2.5rem; --thickness:3px;"}
                        role="progressbar"
                      >
                        <span class="audit-score-text">{pr.score}</span>
                      </div>
                    </td>
                    <td class="audit-page-path">{pr.path}</td>
                    <td class="audit-module-name">{short_module(pr.module)}</td>
                    <td><span class="text-success">{pr.pass}</span></td>
                    <td>
                      <%= if pr.fail > 0 do %>
                        <span class="text-error font-semibold">{pr.fail}</span>
                      <% else %>
                        <span class="text-success">{pr.fail}</span>
                      <% end %>
                    </td>
                    <td class="text-base-content/40">{pr.skip}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% else %>
          <div class="audit-empty">
            <p class="empty-state">Click "Run Audit" to audit all pages against approved rules.</p>
          </div>
        <% end %>

        <%!-- Page detail panel --%>
        <%= if @selected_page do %>
          <div class="audit-detail-panel" id="audit-detail">
            <div class="audit-detail-header">
              <h2>{@selected_page.path}</h2>
              <button phx-click="close_detail" class="btn btn-ghost btn-sm">
                <.icon name="hero-x-mark" class="w-4 h-4" />
              </button>
            </div>
            <p class="audit-detail-module">{inspect(@selected_page.module)}</p>

            <table class="table table-sm">
              <thead>
                <tr>
                  <th>Status</th>
                  <th>Category</th>
                  <th>Rule</th>
                  <th>Evidence</th>
                </tr>
              </thead>
              <tbody>
                <%= for f <- Enum.sort_by(@selected_page.findings, & &1.pass?) do %>
                  <tr class={if(not f.pass?, do: "audit-row-fail", else: "")}>
                    <td>
                      <%= if f.pass? do %>
                        <span class="badge badge-success badge-xs">Pass</span>
                      <% else %>
                        <span class="badge badge-error badge-xs">Fail</span>
                      <% end %>
                    </td>
                    <td><span class="badge badge-outline badge-xs">{f.rule_category}</span></td>
                    <td class="audit-rule-content">{f.rule_content}</td>
                    <td>
                      <%= if f.evidence != [] do %>
                        <ul class="audit-issue-list">
                          <%= for ev <- f.evidence do %>
                            <li class="audit-issue">{ev}</li>
                          <% end %>
                        </ul>
                      <% end %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp short_module(module) do
    module
    |> to_string()
    |> String.replace("Elixir.MaestroWeb.", "")
  end

  defp score_color(score) when score >= 80, do: "text-success"
  defp score_color(score) when score >= 50, do: "text-warning"
  defp score_color(_), do: "text-error"

  defp score_row_class(score) when score >= 80, do: ""
  defp score_row_class(score) when score >= 50, do: "audit-row-warn"
  defp score_row_class(_), do: "audit-row-fail"
  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_params(socket, socket.assigns.live_action, params)}
  end

  defp apply_params(socket, _action, _params),
    do: socket
end
