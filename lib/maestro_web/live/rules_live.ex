defmodule MaestroWeb.RulesLive do
  use MaestroWeb, :live_view

  alias Maestro.Ops.Rule
  alias Maestro.Ops.Rules.Coverage

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Rules")
     |> assign(:filter, "all")
     |> assign(:category_filter, nil)
     |> assign(:source_filter, nil)
     |> assign(:editing, nil)
     |> assign(:form, nil)
     |> assign(:show_stats, true)
     |> assign(:selected_dep, nil)
     |> assign(:dep_rules_preview, [])
     |> assign(:deps_info, Coverage.by_library())
     |> assign(:skills, Coverage.skills())
     |> load_rules()}
  end

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    {:noreply, socket |> assign(:filter, status) |> load_rules()}
  end

  def handle_event("filter_category", %{"category" => cat}, socket) do
    cat = if cat == "", do: nil, else: cat
    {:noreply, socket |> assign(:category_filter, cat) |> load_rules()}
  end

  def handle_event("filter_source", %{"source" => source}, socket) do
    source = if source == "", do: nil, else: source
    {:noreply, socket |> assign(:source_filter, source) |> load_rules()}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply, socket |> assign(:category_filter, nil) |> assign(:source_filter, nil) |> load_rules()}
  end

  def handle_event("toggle_stats", _params, socket) do
    {:noreply, assign(socket, :show_stats, !socket.assigns.show_stats)}
  end

  def handle_event("select_dep", %{"dep" => dep}, socket) do
    if dep == socket.assigns.selected_dep do
      {:noreply, assign(socket, selected_dep: nil, dep_rules_preview: [])}
    else
      preview = load_dep_file_rules(dep)
      {:noreply, assign(socket, selected_dep: dep, dep_rules_preview: preview)}
    end
  end

  def handle_event("close_dep", _params, socket) do
    {:noreply, assign(socket, selected_dep: nil, dep_rules_preview: [])}
  end

  def handle_event("approve", %{"id" => id}, socket) do
    rule = Rule.by_id!(id)
    Rule.approve(rule)
    {:noreply, socket |> load_rules() |> put_flash(:info, "Rule approved")}
  end

  def handle_event("retire", %{"id" => id}, socket) do
    rule = Rule.by_id!(id)
    Rule.retire(rule, %{retired_reason: "Retired from UI"})
    {:noreply, socket |> load_rules() |> put_flash(:info, "Rule retired")}
  end

  def handle_event("mark_linter", %{"id" => id}, socket) do
    rule = Rule.by_id!(id)
    Rule.mark_linter(rule)
    {:noreply, socket |> load_rules() |> put_flash(:info, "Marked as linter rule")}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    rule = Rule.by_id!(id)
    Rule.destroy(rule)
    {:noreply, socket |> load_rules() |> put_flash(:info, "Rule deleted")}
  end

  def handle_event("new_rule", _params, socket) do
    form = AshPhoenix.Form.for_create(Rule, :create, as: "rule") |> to_form()
    {:noreply, assign(socket, editing: :new, form: form)}
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, editing: nil, form: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    rule = Rule.by_id!(id)
    form = AshPhoenix.Form.for_update(rule, :update, as: "rule") |> to_form()
    {:noreply, assign(socket, editing: rule, form: form)}
  end

  def handle_event("validate", %{"rule" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form.source, params) |> to_form()
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"rule" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form.source, params: params) do
      {:ok, _rule} ->
        verb = if socket.assigns.editing == :new, do: "created", else: "updated"
        {:noreply,
         socket
         |> assign(editing: nil, form: nil)
         |> load_rules()
         |> put_flash(:info, "Rule #{verb}")}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  defp load_rules(socket) do
    all_rules = Rule.read!()

    rules =
      all_rules
      |> filter_by_status(socket.assigns.filter)
      |> filter_by_category(socket.assigns[:category_filter])
      |> filter_by_source(socket.assigns[:source_filter])
      |> Enum.sort_by(& &1.updated_at, {:desc, DateTime})

    counts = %{
      all: length(all_rules),
      proposed: Enum.count(all_rules, &(&1.status == :proposed)),
      approved: Enum.count(all_rules, &(&1.status == :approved)),
      retired: Enum.count(all_rules, &(&1.status == :retired)),
      linter: Enum.count(all_rules, &(&1.status == :linter))
    }

    assign(socket, rules: rules, counts: counts, deps_info: Coverage.by_library())
  end

  defp filter_by_status(rules, "proposed"), do: Enum.filter(rules, &(&1.status == :proposed))
  defp filter_by_status(rules, "approved"), do: Enum.filter(rules, &(&1.status == :approved))
  defp filter_by_status(rules, "retired"), do: Enum.filter(rules, &(&1.status == :retired))
  defp filter_by_status(rules, "linter"), do: Enum.filter(rules, &(&1.status == :linter))
  defp filter_by_status(rules, _), do: rules

  defp filter_by_source(rules, nil), do: rules
  defp filter_by_source(rules, source), do: Enum.filter(rules, &(&1.source_project_slug == source))

  defp filter_by_category(rules, nil), do: rules
  defp filter_by_category(rules, cat) do
    cat_atom = String.to_existing_atom(cat)
    Enum.filter(rules, &(&1.category == cat_atom))
  end

  defp status_badge_class(:proposed), do: "badge-warning"
  defp status_badge_class(:approved), do: "badge-success"
  defp status_badge_class(:retired), do: "badge-ghost"
  defp status_badge_class(:linter), do: "badge-info"

  defp severity_badge_class(:must), do: "badge-error"
  defp severity_badge_class(:should), do: "badge-warning"
  defp severity_badge_class(:prefer), do: "badge-info"

  @categories [
    :architecture, :liveview, :ash, :heex, :css, :elixir,
    :testing, :deployment, :pubsub, :forms, :components,
    :routing, :security
  ]


  defp load_dep_file_rules(dep) do
    deps_dir = Path.expand("deps")
    dep_path = Path.join(deps_dir, dep)

    paths =
      [Path.join(dep_path, "usage-rules.md")] ++
      if File.dir?(Path.join(dep_path, "usage-rules")) do
        Path.wildcard(Path.join([dep_path, "usage-rules", "*.md"]))
      else
        []
      end

    for path <- paths, File.exists?(path) do
      name = if String.ends_with?(path, "usage-rules.md"),
        do: "main",
        else: Path.basename(path, ".md")

      rules = path
        |> File.read!()
        |> String.split("\n")
        |> Enum.filter(&Regex.match?(~r/^- /, &1))
        |> Enum.map(&String.trim_leading(&1, "- "))
        |> Enum.map(&String.slice(&1, 0, 200))

      %{name: name, path: Path.relative_to_cwd(path), rules: rules}
    end
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :categories, @categories)

    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="max-w-7xl mx-auto px-8 py-12">
        <div class="flex items-center justify-between mb-6">
          <div>
            <h1 class="text-4xl font-bold">Rules</h1>
            <p class="text-base-content/60 mt-1">
              {Map.get(@counts, :approved, 0)} approved · {Map.get(@counts, :linter, 0)} linter · {Map.get(@counts, :retired, 0)} retired · {Map.get(@counts, :all, 0)} total
            </p>
          </div>
          <div class="flex gap-2">
            <button phx-click="toggle_stats" class="btn btn-ghost btn-sm">
              <.icon name="hero-chart-bar" class="w-4 h-4" />
              {if @show_stats, do: "Hide", else: "Show"} Stats
            </button>
            <button phx-click="new_rule" class="btn btn-primary btn-sm">
              <.icon name="hero-plus" class="w-4 h-4" /> New Rule
            </button>
          </div>
        </div>

        <%!-- Curation Coverage Dashboard --%>
        <%= if @show_stats do %>
          <div class="card bg-base-200 mb-6">
            <div class="card-body p-4">
              <h3 class="font-semibold text-sm mb-3">Curation Coverage</h3>
              <div class="overflow-x-auto">
                <table class="table table-xs">
                  <thead>
                    <tr>
                      <th>Source</th>
                      <th class="text-center">Version</th>
                      <th class="text-center">Rules</th>
                      <th class="text-center">Files</th>
                      <th class="text-center">Coverage</th>
                      <th class="text-center text-success">Approved</th>
                      <th class="text-center text-info">Linter</th>
                      <th class="text-center text-base-content/40">Retired</th>
                      <th class="text-center text-warning">Pending</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for d <- @deps_info do %>
                      <tr class="hover cursor-pointer" phx-click="select_dep" phx-value-dep={d.dep}>
                        <td class="font-mono text-xs font-semibold">{d.dep}</td>
                        <td class="text-center text-xs text-base-content/50">{d.version}</td>
                        <td class="text-center">{d.source_count}</td>
                        <td class="text-center text-xs text-base-content/50">{d.file_count}</td>
                        <td class="text-center">
                          <div class="flex items-center gap-2 justify-center">
                            <progress class={["progress w-16", cond do
                              d.coverage_pct >= 80 -> "progress-success"
                              d.coverage_pct >= 40 -> "progress-warning"
                              true -> "progress-error"
                            end]} value={d.coverage_pct} max="100" />
                            <span class="text-xs">{d.coverage_pct}%</span>
                          </div>
                        </td>
                        <td class="text-center text-success">{d.approved}</td>
                        <td class="text-center text-info">{d.linter}</td>
                        <td class="text-center text-base-content/40">{d.retired}</td>
                        <td class={["text-center", d.proposed > 0 && "text-warning font-bold"]}>{d.proposed}</td>
                      </tr>
                    <% end %>
                  </tbody>
                  <tfoot>
                    <tr class="font-semibold">
                      <td>Total</td>
                      <td />
                      <td class="text-center">{Enum.sum(Enum.map(@deps_info, & &1.source_count))}</td>
                      <td class="text-center">{Enum.sum(Enum.map(@deps_info, & &1.file_count))}</td>
                      <td />
                      <td class="text-center text-success">{Enum.sum(Enum.map(@deps_info, & &1.approved))}</td>
                      <td class="text-center text-info">{Enum.sum(Enum.map(@deps_info, & &1.linter))}</td>
                      <td class="text-center text-base-content/40">{Enum.sum(Enum.map(@deps_info, & &1.retired))}</td>
                      <td class="text-center text-warning">{Enum.sum(Enum.map(@deps_info, & &1.proposed))}</td>
                    </tr>
                  </tfoot>
                </table>
              </div>
            </div>
          </div>

          <%!-- Skills --%>
          <%= if @skills != [] do %>
            <div class="flex gap-2 mt-3">
              <%= for skill <- @skills do %>
                <div class="badge badge-outline gap-1">
                  <span class="font-semibold">{skill.name}</span>
                  <span class="text-base-content/40">{length(skill.library_names)} libs</span>
                </div>
              <% end %>
            </div>
          <% end %>

          <%!-- Dep drill-down --%>
          <%= if @selected_dep do %>
            <div class="card bg-base-200 mb-4">
              <div class="card-body p-4">
                <div class="flex items-center justify-between mb-2">
                  <h3 class="font-semibold text-sm">{@selected_dep} — source rules</h3>
                  <button phx-click="close_dep" class="btn btn-ghost btn-xs">Close</button>
                </div>
                <%= for file <- @dep_rules_preview do %>
                  <div class="mb-3">
                    <div class="text-xs font-mono text-base-content/50 mb-1">{file.path}</div>
                    <ul class="space-y-1">
                      <%= for rule <- file.rules do %>
                        <li class="text-xs pl-3 border-l-2 border-base-300">{rule}</li>
                      <% end %>
                    </ul>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        <% end %>

        <%!-- Status filter tabs --%>
        <div class="tabs tabs-boxed mb-4">
          <button phx-click="filter" phx-value-status="all" class={["tab", @filter == "all" && "tab-active"]}>
            All ({Map.get(@counts, :all, 0)})
          </button>
          <button phx-click="filter" phx-value-status="approved" class={["tab", @filter == "approved" && "tab-active"]}>
            Approved ({Map.get(@counts, :approved, 0)})
          </button>
          <button phx-click="filter" phx-value-status="linter" class={["tab", @filter == "linter" && "tab-active"]}>
            Linter ({Map.get(@counts, :linter, 0)})
          </button>
          <button phx-click="filter" phx-value-status="retired" class={["tab", @filter == "retired" && "tab-active"]}>
            Retired ({Map.get(@counts, :retired, 0)})
          </button>
          <button phx-click="filter" phx-value-status="proposed" class={["tab", @filter == "proposed" && "tab-active"]}>
            Proposed ({Map.get(@counts, :proposed, 0)})
          </button>
        </div>

        <%!-- Filters row --%>
        <div class="flex gap-3 mb-6">
          <select class="select select-bordered select-sm" phx-change="filter_category" name="category">
            <option value="">All categories</option>
            <%= for cat <- @categories do %>
              <option value={cat} selected={to_string(cat) == (@category_filter || "")}>{cat}</option>
            <% end %>
          </select>

          <select class="select select-bordered select-sm" phx-change="filter_source" name="source">
            <option value="">All sources</option>
            <%= for d <- @deps_info do %>
              <option value={d.dep} selected={d.dep == (@source_filter || "")}>{d.dep} ({d.source_count})</option>
            <% end %>
          </select>

          <%= if @category_filter || @source_filter do %>
            <button phx-click="clear_filters" class="btn btn-ghost btn-sm">
              Clear filters
            </button>
          <% end %>
        </div>

        <%!-- Rule form modal --%>
        <%= if @editing do %>
          <div class="card bg-base-200 shadow-lg mb-6">
            <div class="card-body">
              <h2 class="card-title">
                {if @editing == :new, do: "New Rule", else: "Edit Rule"}
              </h2>
              <.form for={@form} phx-change="validate" phx-submit="save" id="rule-form">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div class="md:col-span-2">
                    <label class="label">Content</label>
                    <textarea name="rule[content]" class="textarea textarea-bordered w-full" rows="3" required>{@form[:content].value}</textarea>
                  </div>

                  <div>
                    <label class="label">Category</label>
                    <select name="rule[category]" class="select select-bordered w-full" required>
                      <option value="">Select...</option>
                      <%= for cat <- @categories do %>
                        <option value={cat} selected={to_string(cat) == to_string(@form[:category].value)}>{cat}</option>
                      <% end %>
                    </select>
                  </div>

                  <div>
                    <label class="label">Severity</label>
                    <select name="rule[severity]" class="select select-bordered w-full">
                      <option value="must" selected={to_string(@form[:severity].value) == "must"}>MUST</option>
                      <option value="should" selected={to_string(@form[:severity].value) == "should"}>SHOULD</option>
                      <option value="prefer" selected={to_string(@form[:severity].value) == "prefer"}>PREFER</option>
                    </select>
                  </div>

                  <div>
                    <label class="label">Source Project</label>
                    <input type="text" name="rule[source_project_slug]" value={@form[:source_project_slug].value} class="input input-bordered w-full" placeholder="e.g. calvin" />
                  </div>

                  <div>
                    <label class="label">Source Commit</label>
                    <input type="text" name="rule[source_commit]" value={@form[:source_commit].value} class="input input-bordered w-full" placeholder="SHA" />
                  </div>

                  <div class="md:col-span-2">
                    <label class="label">Source Context (why this rule exists)</label>
                    <textarea name="rule[source_context]" class="textarea textarea-bordered w-full" rows="2">{@form[:source_context].value}</textarea>
                  </div>

                  <div>
                    <label class="label">Applies To (comma-separated)</label>
                    <input type="text" name="rule[applies_to][]" value={Enum.join(@form[:applies_to].value || ["all"], ",")} class="input input-bordered w-full" placeholder="all" />
                  </div>

                  <div>
                    <label class="label">Tags (comma-separated)</label>
                    <input type="text" name="rule[tags][]" value={Enum.join(@form[:tags].value || [], ",")} class="input input-bordered w-full" placeholder="pubsub, liveview" />
                  </div>
                </div>

                <div class="mt-4 flex gap-2">
                  <button type="submit" class="btn btn-primary">Save</button>
                  <button type="button" phx-click="cancel_edit" class="btn btn-ghost">Cancel</button>
                </div>
              </.form>
            </div>
          </div>
        <% end %>

        <%!-- Rules list --%>
        <div class="space-y-3">
          <%= for rule <- @rules do %>
            <div class="card bg-base-100 shadow-sm border border-base-300">
              <div class="card-body py-4 px-6">
                <div class="flex items-start justify-between gap-4">
                  <div class="flex-1">
                    <div class="flex items-center gap-2 mb-2">
                      <span class={["badge badge-sm", status_badge_class(rule.status)]}>{rule.status}</span>
                      <span class={["badge badge-sm badge-outline", severity_badge_class(rule.severity)]}>{rule.severity}</span>
                      <span class="badge badge-sm badge-outline">{rule.category}</span>
                      <%= if rule.source_project_slug do %>
                        <span class="text-xs text-base-content/50">from {rule.source_project_slug}</span>
                      <% end %>
                      <%= if rule.source_commit do %>
                        <code class="text-xs text-base-content/40">{String.slice(rule.source_commit, 0..6)}</code>
                      <% end %>
                    </div>
                    <p class="text-sm whitespace-pre-wrap">{rule.content}</p>
                    <%= if rule.retired_reason do %>
                      <p class="text-xs text-base-content/50 mt-1">
                        Retired: {rule.retired_reason}
                      </p>
                    <% end %>
                    <%= if rule.source_context && !String.contains?(rule.source_context, "(auto-ingested)") do %>
                      <p class="text-xs text-base-content/50 mt-1">
                        {rule.source_context}
                      </p>
                    <% end %>
                    <%= if rule.tags && rule.tags != [] do %>
                      <div class="flex gap-1 mt-2">
                        <%= for tag <- rule.tags do %>
                          <span class="badge badge-xs">{tag}</span>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                  <div class="flex gap-1 shrink-0">
                    <%= if rule.status == :proposed do %>
                      <button phx-click="approve" phx-value-id={rule.id} class="btn btn-xs btn-success btn-outline">Approve</button>
                      <button phx-click="mark_linter" phx-value-id={rule.id} class="btn btn-xs btn-info btn-outline">Linter</button>
                    <% end %>
                    <button phx-click="edit" phx-value-id={rule.id} class="btn btn-xs btn-ghost">Edit</button>
                    <%= if rule.status not in [:retired, :linter] do %>
                      <button phx-click="retire" phx-value-id={rule.id} class="btn btn-xs btn-ghost text-warning">Retire</button>
                    <% end %>
                    <button phx-click="delete" phx-value-id={rule.id} class="btn btn-xs btn-ghost text-error" data-confirm="Delete this rule permanently?">Delete</button>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
          <%= if @rules == [] do %>
            <div class="text-center py-12 text-base-content/50">
              No rules found. Create one or seed from Calvin's CLAUDE.md.
            </div>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
