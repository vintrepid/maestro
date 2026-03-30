defmodule MaestroWeb.Components.RulesCurationTable do
  @moduledoc "Cinder collection table for rule curation."
  use MaestroWeb, :html

  attr :query, :any, required: true
  attr :url_state, :any, required: true
  attr :status_options, :list, required: true
  attr :category_options, :list, required: true
  attr :bundle_options, :list, required: true

  def rules_table(assigns) do
    ~H"""
    <Cinder.collection
      id="rules-table"
      query={@query}
      url_state={@url_state}
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
        <span class={["badge badge-sm", status_badge(rule.status)]}>{rule.status}</span>
      </:col>

      <:col
        :let={rule}
        field="severity"
        label="Sev"
        sort
        filter={[type: :select, options: [{"Must", "must"}, {"Should", "should"}, {"Prefer", "prefer"}]]}
      >
        <span class={["badge badge-sm badge-outline", severity_badge(rule.severity)]}>
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
        <span class={["badge badge-sm", bundle_badge(rule.bundle)]}>{rule.bundle}</span>
      </:col>

      <:col :let={rule} field="priority" label="Pri" sort>
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
        <p class="truncated">{String.slice(rule.content, 0, 200)}</p>
      </:col>

      <:col :let={rule} field="notes" label="Notes">
        <form phx-change="save_notes" phx-debounce="blur" id={"notes-form-#{rule.id}"}>
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
        <.rule_actions rule={rule} />
      </:col>
    </Cinder.collection>
    """
  end

  attr :rule, :map, required: true

  defp rule_actions(assigns) do
    ~H"""
    <div class="join">
      <%= if @rule.status == :proposed do %>
        <button phx-click="approve" phx-value-id={@rule.id} class="btn btn-xs btn-success btn-outline">
          Approve
        </button>
        <button phx-click="mark_linter" phx-value-id={@rule.id} class="btn btn-xs btn-info btn-outline">
          Linter
        </button>
        <button phx-click="mark_anti_pattern" phx-value-id={@rule.id} class="btn btn-xs btn-error btn-outline">
          Anti
        </button>
      <% end %>
      <%= if @rule.status not in [:retired, :linter, :anti_pattern] do %>
        <button phx-click="retire" phx-value-id={@rule.id} class="btn btn-xs btn-ghost text-warning">
          Retire
        </button>
      <% end %>
      <button phx-click="edit" phx-value-id={@rule.id} class="btn btn-xs btn-ghost">
        <.icon name="hero-pencil" class="w-3 h-3" />
      </button>
      <button
        phx-click="delete"
        phx-value-id={@rule.id}
        class="btn btn-xs btn-ghost text-error"
        data-confirm="Delete?"
      >
        <.icon name="hero-trash" class="w-3 h-3" />
      </button>
    </div>
    """
  end

  defp status_badge(:proposed), do: "badge-warning"
  defp status_badge(:approved), do: "badge-success"
  defp status_badge(:retired), do: "badge-ghost"
  defp status_badge(:linter), do: "badge-info"
  defp status_badge(:anti_pattern), do: "badge-error"
  defp status_badge(_), do: ""

  defp severity_badge(:must), do: "badge-error"
  defp severity_badge(:should), do: "badge-warning"
  defp severity_badge(:prefer), do: "badge-info"
  defp severity_badge(_), do: ""

  defp bundle_badge("universal"), do: "badge-primary"
  defp bundle_badge(:universal), do: "badge-primary"
  defp bundle_badge("ui"), do: "badge-secondary"
  defp bundle_badge(:ui), do: "badge-secondary"
  defp bundle_badge("model"), do: "badge-accent"
  defp bundle_badge(:model), do: "badge-accent"
  defp bundle_badge("devops"), do: "badge-info"
  defp bundle_badge(:devops), do: "badge-info"
  defp bundle_badge("maestro"), do: "badge-warning"
  defp bundle_badge(:maestro), do: "badge-warning"
  defp bundle_badge(_), do: "badge-ghost"

  defp priority_color(p) when p >= 80, do: "text-error font-semibold"
  defp priority_color(p) when p >= 60, do: "text-warning"
  defp priority_color(_), do: "text-base-content/50"
end
