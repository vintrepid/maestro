defmodule MaestroWeb.AuditLive do
  @moduledoc """
  Code Audit page — thin shell over Maestro.Ops.Audit.

  All domain logic (running audits, fixing, querying results) lives in the Audit
  resource. This LiveView translates user intent into Audit function calls.
  """

  use MaestroWeb, :live_view
  use Cinder.UrlSync

  alias Maestro.Ops.Audit.Facade, as: Audit

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Audit.subscribe()

    latest = Audit.latest_completed()
    giulia_up = connected?(socket) and Audit.deep_audit_available?()

    {:ok,
     socket
     |> assign(:page_title, "Code Audit")
     |> assign(:audit, latest)
     |> assign(:query, Audit.results_query(latest))
     |> assign(:by_category, Audit.category_summary(latest))
     |> assign(:view_mode, "modules")
     |> assign(:selected_result, nil)
     |> assign(:module_dag, nil)
     |> assign(:running, false)
     |> assign(:filter_approved, true)
     |> assign(:filter_proposed, false)
     |> assign(:filter_linter, true)
     |> assign(:filter_giulia, giulia_up)
     |> assign(:giulia_available, giulia_up)}
  end

  @impl true
  def handle_params(params, uri, socket) do
    socket = Cinder.UrlSync.handle_params(params, uri, socket)
    {:noreply, socket}
  end

  @impl true
  def handle_event("run_audit", _params, socket) do
    send(self(), :do_audit)
    {:noreply, assign(socket, :running, true)}
  end

  def handle_event("toggle_filter", %{"filter" => filter}, socket) do
    key = String.to_existing_atom("filter_#{filter}")
    {:noreply, assign(socket, key, not Map.get(socket.assigns, key))}
  end

  def handle_event("toggle_view", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :view_mode, mode)}
  end

  def handle_event("recheck_giulia", _params, socket) do
    {:noreply, assign(socket, :giulia_available, Audit.deep_audit_available?())}
  end

  def handle_event("select_page", %{"id" => id}, socket) do
    result = Audit.find_result(id)
    dag = if result, do: Audit.fetch_module_dag(result.module_name), else: nil

    {:noreply,
     socket
     |> assign(:selected_result, result)
     |> assign(:module_dag, dag)}
  end

  def handle_event("close_detail", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_result, nil)
     |> assign(:module_dag, nil)}
  end

  def handle_event("fix_all", _params, socket) do
    case socket.assigns.audit do
      nil ->
        {:noreply, socket}

      audit ->
        {:ok, fixed_count} = Audit.fix_all(audit)

        {:noreply,
         put_flash(socket, :info, "Fixed #{fixed_count} file(s). Re-run audit to see results.")}
    end
  end

  @impl true
  def handle_info(:do_audit, socket) do
    Audit.run_audit(
      approved: socket.assigns.filter_approved,
      proposed: socket.assigns.filter_proposed,
      linter: socket.assigns.filter_linter,
      deep: socket.assigns.filter_giulia
    )

    {:noreply, socket}
  end

  def handle_info({:audit_changed, _action, _data}, socket) do
    latest = Audit.latest_completed()

    socket =
      if socket.assigns.selected_result do
        if latest && Audit.result_exists?(latest, socket.assigns.selected_result.module_name) do
          socket
        else
          socket |> assign(:selected_result, nil) |> assign(:module_dag, nil)
        end
      else
        socket
      end

    {:noreply,
     socket
     |> assign(:audit, latest)
     |> assign(:query, Audit.results_query(latest))
     |> assign(:by_category, Audit.category_summary(latest))
     |> assign(:running, false)
     |> refresh_table()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="page-section">
        <div class="page-header">
          <h1>Code Audit</h1>
          <p class="description">
            All modules × all rules (Maestro + Giulia AST analysis).
          </p>
        </div>

        <%= if @giulia_available do %>
          <.live_component
            module={MaestroWeb.Components.GiuliaSkillsCatalog}
            id="giulia-skills-catalog"
          />
        <% end %>

        <div class="audit-controls">
          <button phx-click="run_audit" class="btn btn-primary btn-sm" disabled={@running}>
            <%= if @running do %>
              <span class="loading loading-spinner loading-sm"></span> Running...
            <% else %>
              <.icon name="hero-play" class="w-4 h-4" /> Run Audit
            <% end %>
          </button>

          <div class="flex items-center gap-3">
            <label class="label cursor-pointer gap-1">
              <input
                type="checkbox"
                class="checkbox checkbox-xs checkbox-success"
                checked={@filter_approved}
                phx-click="toggle_filter"
                phx-value-filter="approved"
              />
              <span class="label-text text-xs">Approved</span>
            </label>
            <label class="label cursor-pointer gap-1">
              <input
                type="checkbox"
                class="checkbox checkbox-xs"
                checked={@filter_proposed}
                phx-click="toggle_filter"
                phx-value-filter="proposed"
              />
              <span class="label-text text-xs">Proposed</span>
            </label>
            <label class="label cursor-pointer gap-1">
              <input
                type="checkbox"
                class="checkbox checkbox-xs checkbox-warning"
                checked={@filter_linter}
                phx-click="toggle_filter"
                phx-value-filter="linter"
              />
              <span class="label-text text-xs">Linter</span>
            </label>
            <label class="label cursor-pointer gap-1">
              <input
                type="checkbox"
                class="checkbox checkbox-xs checkbox-info"
                checked={@filter_giulia}
                disabled={not @giulia_available}
                phx-click="toggle_filter"
                phx-value-filter="giulia"
              />
              <span class={"label-text text-xs #{if not @giulia_available, do: "opacity-40"}"}>
                Giulia
              </span>
            </label>
          </div>

          <%= if @audit && @audit.total_fail > 0 do %>
            <button phx-click="fix_all" class="btn btn-warning btn-sm">
              <.icon name="hero-wrench-screwdriver" class="w-4 h-4" /> Fix All
            </button>
          <% end %>
        </div>

        <%= if @audit && @audit.status == :completed do %>
          <div class="audit-summary">
            <div class="stats shadow">
              <div class="stat">
                <div class="stat-title">Modules</div>
                <div class="stat-value">{@audit.total_modules}</div>
              </div>
              <div class="stat">
                <div class="stat-title">Avg Score</div>
                <div class="stat-value">{round(@audit.avg_score || 0)}%</div>
              </div>
              <div class="stat">
                <div class="stat-title">Pass</div>
                <div class="stat-value text-success">{@audit.total_pass_modules}</div>
              </div>
              <div class="stat">
                <div class="stat-title">Fail</div>
                <div class="stat-value text-error">{@audit.total_results}</div>
              </div>
            </div>
          </div>
        <% end %>

        <%= if @audit do %>
          <div class="tabs tabs-boxed mb-4">
            <a
              class={["tab", @view_mode == "modules" && "tab-active"]}
              phx-click="toggle_view"
              phx-value-mode="modules"
            >
              By Module
            </a>
            <a
              class={["tab", @view_mode == "categories" && "tab-active"]}
              phx-click="toggle_view"
              phx-value-mode="categories"
            >
              By Issue Type
            </a>
          </div>

          <%= if @view_mode == "modules" do %>
            <Cinder.collection
              id="audit-results-table"
              query={@query}
              url_state={@url_state}
              page_size={50}
              theme="daisy_ui"
            >
              <:col :let={result} field="score" label="Score" sort>
                <div
                  class={["radial-progress", score_color(result.score)]}
                  style={"--value:#{result.score}; --size:2.5rem; --thickness:3px;"}
                  role="progressbar"
                >
                  <span class="audit-score-text">{result.score}</span>
                </div>
              </:col>
              <:col :let={result} field="path" label="Path" sort>
                <span
                  class="audit-page-path cursor-pointer hover:underline"
                  phx-click="select_page"
                  phx-value-id={result.id}
                >
                  {result.path}
                </span>
              </:col>
              <:col :let={result} field="module_name" label="Module" sort>
                <span class="audit-module-name">{short_module(result.module_name)}</span>
              </:col>
              <:col :let={result} field="pass" label="Pass" sort>
                <span class="text-success">{result.pass}</span>
              </:col>
              <:col :let={result} field="fail" label="Fail" sort>
                <%= if result.fail > 0 do %>
                  <span class="text-error font-semibold">{result.fail}</span>
                <% else %>
                  <span class="text-success">{result.fail}</span>
                <% end %>
              </:col>
              <:col :let={result} field="skip" label="Skip" sort>
                <span class="text-base-content/40">{result.skip}</span>
              </:col>
            </Cinder.collection>
          <% else %>
            <table class="table table-sm table-zebra">
              <thead>
                <tr>
                  <th>Issue Type</th>
                  <th>Count</th>
                  <th>Modules</th>
                </tr>
              </thead>
              <tbody>
                <%= for {category, %{count: count, modules: modules}} <- @by_category do %>
                  <tr>
                    <td><span class="badge badge-outline">{category}</span></td>
                    <td><span class="text-error font-semibold">{count}</span></td>
                    <td>
                      <div class="flex flex-wrap gap-1">
                        <%= for mod <- modules do %>
                          <span class="badge badge-ghost badge-xs">{short_module(mod)}</span>
                        <% end %>
                      </div>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          <% end %>
        <% else %>
          <div class="audit-empty">
            <p class="empty-state">Click "Run Audit" to analyze the project.</p>
          </div>
        <% end %>

        <%!-- Detail panel --%>
        <%= if @selected_result do %>
          <div class="audit-detail-panel" id="audit-detail">
            <div class="audit-detail-header">
              <h2>{@selected_result.path}</h2>
              <button phx-click="close_detail" class="btn btn-ghost btn-sm">
                <.icon name="hero-x-mark" class="w-4 h-4" />
              </button>
            </div>
            <p class="audit-detail-module">{@selected_result.module_name}</p>

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
                <%= for f <- Enum.sort_by(@selected_result.findings, & &1["pass?"]) do %>
                  <tr class={if(not f["pass?"], do: "audit-row-fail", else: "")}>
                    <td>
                      <%= if f["pass?"] do %>
                        <span class="badge badge-success badge-xs">Pass</span>
                      <% else %>
                        <span class="badge badge-error badge-xs">Fail</span>
                      <% end %>
                    </td>
                    <td><span class="badge badge-outline badge-xs">{f["rule_category"]}</span></td>
                    <td class="audit-rule-content">{f["rule_content"]}</td>
                    <td>
                      <%= if f["evidence"] && f["evidence"] != [] do %>
                        <ul class="audit-issue-list">
                          <%= for ev <- f["evidence"] do %>
                            <li class="audit-issue">{ev}</li>
                          <% end %>
                        </ul>
                      <% end %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>

            <%= if @module_dag do %>
              <div class="mt-4">
                <h3 class="text-sm font-semibold mb-2">Dependency Graph</h3>
                <div id="audit-dag" phx-hook="Mermaid" data-mermaid={@module_dag}>
                  <pre class="mermaid">{@module_dag}</pre>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  # -- View helpers (presentation only, no domain logic) --

  defp refresh_table(socket) do
    Cinder.Refresh.refresh_table(socket, "audit-results-table")
  end

  defp short_module(module_name) do
    module_name
    |> String.replace("Elixir.MaestroWeb.", "")
    |> String.replace("Elixir.Maestro.", "")
    |> String.replace("Elixir.Mix.Tasks.", "mix ")
    |> String.replace("Elixir.", "")
  end

  defp score_color(score) when score >= 80, do: "text-success"
  defp score_color(score) when score >= 50, do: "text-warning"
  defp score_color(_), do: "text-error"
end
