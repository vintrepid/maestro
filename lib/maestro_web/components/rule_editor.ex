defmodule MaestroWeb.Components.RuleEditor do
  @moduledoc """
  Standalone component for viewing and editing a single Rule instance.

  Renders the edit form AND instance actions (approve, retire, mark linter,
  mark anti-pattern, delete). No modal, no page wrapper — the caller decides
  presentation context.

  ## Usage

      <.rule_editor form={@form} editing={@editing} category_options={@category_options} />

  Events emitted (handled by the parent LiveView):
  - `validate`         — form change
  - `save`             — form submit
  - `cancel_edit`      — cancel
  - `approve`          — approve (with id)
  - `retire`           — retire (with id)
  - `mark_linter`      — mark as linter rule (with id)
  - `mark_anti_pattern` — mark as anti-pattern (with id)
  - `delete`           — delete (with id)
  """
  use MaestroWeb, :html

  @severity_options [{"MUST", "must"}, {"SHOULD", "should"}, {"PREFER", "prefer"}]
  @bundle_options [
    {"Universal", "universal"},
    {"UI", "ui"},
    {"Model", "model"},
    {"DevOps", "devops"},
    {"Maestro", "maestro"}
  ]

  attr :form, :any, required: true
  attr :editing, :any, required: true, doc: ":new or the rule struct being edited"
  attr :category_options, :list, required: true

  def rule_editor(assigns) do
    assigns =
      assigns
      |> assign_new(:severity_options, fn -> @severity_options end)
      |> assign_new(:bundle_options, fn -> @bundle_options end)

    ~H"""
    <div id="rule-editor">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-bold">
          {if @editing == :new, do: "New Rule", else: "Edit Rule"}
        </h3>
        <.rule_status_badge :if={@editing != :new} status={@editing.status} />
      </div>

      <.rule_instance_actions :if={@editing != :new} rule={@editing} />

      <.form for={@form} phx-change="validate" phx-submit="save" id="rule-form">
        <.input field={@form[:content]} type="textarea" label="Content" rows={4} required />

        <div class="grid grid-cols-2 gap-x-4">
          <.input field={@form[:category]} type="select" label="Category" prompt="Select..." options={@category_options} required />
          <.input field={@form[:severity]} type="select" label="Severity" options={@severity_options} />
          <.input field={@form[:bundle]} type="select" label="Bundle" prompt="Select..." options={@bundle_options} />
          <.input field={@form[:source_project_slug]} label="Source Project" placeholder="e.g. maestro" />
        </div>

        <.input field={@form[:source_context]} label="Source Context" placeholder="Why this rule exists" />
        <.input
          field={@form[:tags]}
          label="Tags (comma-separated)"
          placeholder="liveview, architecture"
          value={tags_display(@form[:tags].value)}
        />
        <.input field={@form[:notes]} type="textarea" label="Notes" rows={2} />

        <div class="flex justify-end gap-2 mt-4">
          <button type="button" phx-click="cancel_edit" class="btn btn-ghost">Cancel</button>
          <button type="submit" class="btn btn-primary">Save</button>
        </div>
      </.form>
    </div>
    """
  end

  # -- Instance actions --

  attr :rule, :map, required: true

  defp rule_instance_actions(assigns) do
    ~H"""
    <div class="flex flex-wrap gap-2 mb-4">
      <%= if @rule.status == :proposed do %>
        <button phx-click="approve" phx-value-id={@rule.id} class="btn btn-sm btn-success btn-outline">
          <.icon name="hero-check" class="w-4 h-4" /> Approve
        </button>
        <button phx-click="mark_linter" phx-value-id={@rule.id} class="btn btn-sm btn-info btn-outline">
          <.icon name="hero-wrench-screwdriver" class="w-4 h-4" /> Linter
        </button>
        <button phx-click="mark_anti_pattern" phx-value-id={@rule.id} class="btn btn-sm btn-error btn-outline">
          <.icon name="hero-x-circle" class="w-4 h-4" /> Anti-pattern
        </button>
      <% end %>
      <%= if @rule.status not in [:retired, :linter, :anti_pattern] do %>
        <button phx-click="retire" phx-value-id={@rule.id} class="btn btn-sm btn-warning btn-outline">
          <.icon name="hero-archive-box" class="w-4 h-4" /> Retire
        </button>
      <% end %>
      <div class="flex-1"></div>
      <button phx-click="discuss" phx-value-id={@rule.id} class="btn btn-sm btn-secondary btn-outline">
        <.icon name="hero-chat-bubble-left-right" class="w-4 h-4" /> Discuss
      </button>
      <button
        phx-click="delete"
        phx-value-id={@rule.id}
        class="btn btn-sm btn-ghost text-error"
        data-confirm="Delete this rule?"
      >
        <.icon name="hero-trash" class="w-4 h-4" /> Delete
      </button>
    </div>
    """
  end

  # -- Status badge --

  attr :status, :atom, required: true

  defp rule_status_badge(assigns) do
    ~H"""
    <span class={["badge", status_class(@status)]}>{@status}</span>
    """
  end

  defp tags_display(tags) when is_list(tags), do: Enum.join(tags, ", ")
  defp tags_display(tags) when is_binary(tags), do: tags
  defp tags_display(_), do: ""

  defp status_class(:proposed), do: "badge-warning"
  defp status_class(:approved), do: "badge-success"
  defp status_class(:retired), do: "badge-ghost"
  defp status_class(:linter), do: "badge-info"
  defp status_class(:anti_pattern), do: "badge-error"
  defp status_class(_), do: ""
end
