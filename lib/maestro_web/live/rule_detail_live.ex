defmodule MaestroWeb.RuleDetailLive do
  @moduledoc "Detail page for a single Rule — editor, actions, related rules, provenance."
  use MaestroWeb, :live_view

  alias Maestro.Ops.Rule.Facade, as: Rules
  import MaestroWeb.Components.RuleEditor

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {rule, related} = Rules.get_rule_with_related(id)
    {_rule_for_form, form} = Rules.edit_form(id)

    {:ok,
     socket
     |> assign(:page_title, "Rule — #{String.slice(rule.content, 0, 40)}…")
     |> assign(:rule, rule)
     |> assign(:related, related)
     |> assign(:editing, rule)
     |> assign(:form, form)
     |> assign(:category_options, Rules.category_options())}
  end

  def mount(_params, _session, socket) do
    form = Rules.new_form()

    {:ok,
     socket
     |> assign(:page_title, "New Rule")
     |> assign(:rule, nil)
     |> assign(:related, %{superseded_by: nil, supersedes: [], same_category: [], same_tags: []})
     |> assign(:editing, :new)
     |> assign(:form, form)
     |> assign(:category_options, Rules.category_options())}
  end

  @impl true
  def handle_event("validate", %{"rule" => params}, socket) do
    form = Rules.validate_form(socket.assigns.form.source, params)
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"rule" => params}, socket) do
    case Rules.submit_form(socket.assigns.form.source, params) do
      {:ok, rule} ->
        if socket.assigns.editing == :new do
          {:noreply,
           socket
           |> put_flash(:info, "Rule created")
           |> push_navigate(to: ~p"/rules/#{rule.id}")}
        else
          {rule, related} = Rules.get_rule_with_related(rule.id)
          {_, form} = Rules.edit_form(rule.id)

          {:noreply,
           socket
           |> assign(rule: rule, related: related, editing: rule, form: form)
           |> put_flash(:info, "Rule updated")}
        end

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/rules")}
  end

  def handle_event("approve", %{"id" => id}, socket) do
    case Rules.approve_rule(id) do
      :ok -> {:noreply, reload(socket, id) |> put_flash(:info, "Rule approved")}
      {:error, msg} -> {:noreply, put_flash(socket, :error, msg)}
    end
  end

  def handle_event("retire", %{"id" => id}, socket) do
    Rules.retire_rule(id)
    {:noreply, reload(socket, id) |> put_flash(:info, "Rule retired")}
  end

  def handle_event("mark_linter", %{"id" => id}, socket) do
    Rules.mark_linter(id)
    {:noreply, reload(socket, id) |> put_flash(:info, "Marked as linter rule")}
  end

  def handle_event("mark_anti_pattern", %{"id" => id}, socket) do
    Rules.mark_anti_pattern(id)
    {:noreply, reload(socket, id) |> put_flash(:info, "Marked as anti-pattern")}
  end

  def handle_event("discuss", %{"id" => id}, socket) do
    case Rules.discuss_rule(id) do
      {:ok, task} ->
        {:noreply, put_flash(socket, :info, "Discussion task ##{task.id} created")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create discussion task")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    Rules.destroy_rule(id)
    {:noreply, push_navigate(socket, to: ~p"/rules") |> put_flash(:info, "Rule deleted")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="py-4">
        <div class="breadcrumbs text-sm mb-4">
          <ul>
            <li><a href="/rules">Rules</a></li>
            <li>{@rule.category}</li>
          </ul>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div class="lg:col-span-2">
            <.rule_editor form={@form} editing={@editing} category_options={@category_options} />
          </div>

          <div class="space-y-4">
            <.provenance_card rule={@rule} />
            <.supersession_card rule={@rule} related={@related} />
            <.related_rules_card title="Same Category" rules={@related.same_category} />
            <.related_rules_card title="Shared Tags" rules={@related.same_tags} />
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # -- Sidebar cards --

  attr :rule, :map, required: true

  defp provenance_card(assigns) do
    ~H"""
    <div class="card bg-base-200">
      <div class="card-body p-4">
        <h4 class="font-bold text-sm">Provenance</h4>
        <dl class="text-xs space-y-1">
          <div :if={@rule.source_project_slug} class="flex gap-2">
            <dt class="font-semibold w-20">Source</dt>
            <dd class="font-mono">{@rule.source_project_slug}</dd>
          </div>
          <div :if={@rule.source_context} class="flex gap-2">
            <dt class="font-semibold w-20">Context</dt>
            <dd>{@rule.source_context}</dd>
          </div>
          <div :if={@rule.source_commit} class="flex gap-2">
            <dt class="font-semibold w-20">Commit</dt>
            <dd class="font-mono">{String.slice(@rule.source_commit, 0, 8)}</dd>
          </div>
          <div :if={@rule.library} class="flex gap-2">
            <dt class="font-semibold w-20">Library</dt>
            <dd class="font-mono">{@rule.library.name}</dd>
          </div>
          <div :if={@rule.rule_source} class="flex gap-2">
            <dt class="font-semibold w-20">Source File</dt>
            <dd class="font-mono truncate max-w-48">{@rule.rule_source.file_path}</dd>
          </div>
          <div class="flex gap-2">
            <dt class="font-semibold w-20">Created</dt>
            <dd>{Calendar.strftime(@rule.inserted_at, "%Y-%m-%d")}</dd>
          </div>
          <div :if={@rule.approved_at} class="flex gap-2">
            <dt class="font-semibold w-20">Approved</dt>
            <dd>{Calendar.strftime(@rule.approved_at, "%Y-%m-%d")}</dd>
          </div>
          <div class="flex gap-2">
            <dt class="font-semibold w-20">ID</dt>
            <dd class="font-mono text-base-content/40">{String.slice(@rule.id, 0, 8)}</dd>
          </div>
        </dl>
      </div>
    </div>
    """
  end

  attr :rule, :map, required: true
  attr :related, :map, required: true

  defp supersession_card(assigns) do
    ~H"""
    <div :if={@related.superseded_by || @related.supersedes != []} class="card bg-base-200">
      <div class="card-body p-4">
        <h4 class="font-bold text-sm">Supersession</h4>
        <div :if={@related.superseded_by} class="mb-2">
          <span class="badge badge-sm badge-ghost">superseded by</span>
          <a href={~p"/rules/#{@related.superseded_by.id}"} class="link link-primary text-xs block mt-1">
            {String.slice(@related.superseded_by.content, 0, 80)}…
          </a>
        </div>
        <div :if={@related.supersedes != []}>
          <span class="badge badge-sm badge-ghost">supersedes {length(@related.supersedes)}</span>
          <ul class="mt-1 space-y-1">
            <li :for={r <- @related.supersedes} class="text-xs">
              <a href={~p"/rules/#{r.id}"} class="link text-base-content/70 hover:text-primary">
                <span class={["badge badge-xs", status_class(r.status)]}>{r.status}</span>
                {String.slice(r.content, 0, 60)}…
              </a>
            </li>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :rules, :list, required: true

  defp related_rules_card(assigns) do
    ~H"""
    <div :if={@rules != []} class="card bg-base-200">
      <div class="card-body p-4">
        <h4 class="font-bold text-sm">{@title}</h4>
        <ul class="space-y-1">
          <li :for={r <- @rules} class="text-xs">
            <a href={~p"/rules/#{r.id}"} class="link text-base-content/70 hover:text-primary">
              <span class={["badge badge-xs", status_class(r.status)]}>{r.status}</span>
              {String.slice(r.content, 0, 60)}…
            </a>
          </li>
        </ul>
      </div>
    </div>
    """
  end

  # -- Helpers --

  defp reload(socket, id) do
    {rule, related} = Rules.get_rule_with_related(id)
    {_, form} = Rules.edit_form(id)
    assign(socket, rule: rule, related: related, editing: rule, form: form)
  end

  defp status_class(:proposed), do: "badge-warning"
  defp status_class(:approved), do: "badge-success"
  defp status_class(:retired), do: "badge-ghost"
  defp status_class(:linter), do: "badge-info"
  defp status_class(:anti_pattern), do: "badge-error"
  defp status_class(_), do: ""
end
