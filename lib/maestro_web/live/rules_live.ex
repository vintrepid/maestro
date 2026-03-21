defmodule MaestroWeb.RulesLive do
  use MaestroWeb, :live_view

  alias Maestro.Ops.Rule

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Rules")
     |> assign(:filter, "all")
     |> assign(:category_filter, nil)
     |> assign(:editing, nil)
     |> assign(:form, nil)
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
    rules =
      Rule.read!()
      |> filter_by_status(socket.assigns.filter)
      |> filter_by_category(socket.assigns[:category_filter])
      |> Enum.sort_by(& &1.updated_at, {:desc, DateTime})

    counts = %{
      all: length(Rule.read!()),
      proposed: length(Rule.proposed!()),
      approved: length(Rule.approved!())
    }

    assign(socket, rules: rules, counts: counts)
  end

  defp filter_by_status(rules, "proposed"), do: Enum.filter(rules, &(&1.status == :proposed))
  defp filter_by_status(rules, "approved"), do: Enum.filter(rules, &(&1.status == :approved))
  defp filter_by_status(rules, "retired"), do: Enum.filter(rules, &(&1.status == :retired))
  defp filter_by_status(rules, "linter"), do: Enum.filter(rules, &(&1.status == :linter))
  defp filter_by_status(rules, _), do: rules

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
              {Map.get(@counts, :proposed, 0)} proposed · {Map.get(@counts, :approved, 0)} approved · {Map.get(@counts, :all, 0)} total
            </p>
          </div>
          <button phx-click="new_rule" class="btn btn-primary">
            <.icon name="hero-plus" class="w-5 h-5" /> New Rule
          </button>
        </div>

        <%!-- Status filter tabs --%>
        <div class="tabs tabs-boxed mb-6">
          <button phx-click="filter" phx-value-status="all" class={["tab", @filter == "all" && "tab-active"]}>
            All ({Map.get(@counts, :all, 0)})
          </button>
          <button phx-click="filter" phx-value-status="proposed" class={["tab", @filter == "proposed" && "tab-active"]}>
            Proposed ({Map.get(@counts, :proposed, 0)})
          </button>
          <button phx-click="filter" phx-value-status="approved" class={["tab", @filter == "approved" && "tab-active"]}>
            Approved ({Map.get(@counts, :approved, 0)})
          </button>
          <button phx-click="filter" phx-value-status="retired" class={["tab", @filter == "retired" && "tab-active"]}>
            Retired
          </button>
          <button phx-click="filter" phx-value-status="linter" class={["tab", @filter == "linter" && "tab-active"]}>
            Linter
          </button>
        </div>

        <%!-- Category filter --%>
        <div class="mb-6">
          <select class="select select-bordered select-sm" phx-change="filter_category" name="category">
            <option value="">All categories</option>
            <%= for cat <- @categories do %>
              <option value={cat} selected={to_string(cat) == (@category_filter || "")}>{cat}</option>
            <% end %>
          </select>
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
                    <%= if rule.source_context do %>
                      <p class="text-xs text-base-content/50 mt-1">
                        Why: {rule.source_context}
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
