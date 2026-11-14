defmodule MaestroWeb.DependencyComponents do
  @moduledoc "Host semantic primitives for Maestro's shared dependency dashboard."
  use Phoenix.Component

  @doc "Renders one composable page region backed by DaisyUI's card primitive."
  attr :id, :string, default: nil
  attr :title, :string, default: nil
  attr :description, :string, default: nil

  attr :kind, :atom,
    default: :record,
    values: [:dashboard, :collection, :record, :workflow, :inspector]

  attr :heading, :atom, default: :body, values: [:body, :separate]
  attr :density, :atom, default: :normal, values: [:normal, :compact, :flush]
  attr :elevation, :atom, default: :none, values: [:none, :raised, :prominent]
  attr :sticky, :atom, default: :none, values: [:none, :viewport]
  attr :bordered, :boolean, default: true
  attr :rest, :global

  slot :heading_actions
  slot :inner_block, required: true

  @spec region(map()) :: Phoenix.LiveView.Rendered.t()
  def region(assigns) do
    ~H"""
    <section
      id={@id}
      class="app-region card bg-base-100 border border-base-300 p-4"
      data-region={@kind}
      data-heading={@heading}
      data-density={@density}
      data-elevation={@elevation}
      data-sticky={@sticky}
      data-bordered={to_string(@bordered)}
      {@rest}
    >
      <header :if={@title && @heading == :separate} data-slot="header">
        <div>
          <h2>{@title}</h2>
          <p :if={@description}>{@description}</p>
        </div>
        <div :if={@heading_actions != []} class="app-cluster" data-slot="actions">
          {render_slot(@heading_actions)}
        </div>
      </header>
      <div data-slot="body">
        <h2 :if={@title && @heading == :body}>{@title}</h2>
        <p :if={@description && @heading == :body} data-slot="description">
          {@description}
        </p>
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end

  @doc "Renders a button or link with a closed set of application variants."
  attr :href, :string, default: nil
  attr :navigate, :string, default: nil
  attr :patch, :string, default: nil
  attr :type, :string, default: "button", values: ~w(button submit reset)

  attr :variant, :atom,
    default: :primary,
    values: [:primary, :secondary, :outline, :quiet, :success, :danger]

  attr :size, :atom, default: :md, values: [:xs, :sm, :md]
  attr :active, :boolean, default: nil
  attr :soft, :boolean, default: false
  attr :title, :string, default: nil

  attr :rest, :global,
    include: ~w(disabled download form method name rel target value phx-click phx-disable-with)

  slot :inner_block, required: true

  @spec action(map()) :: Phoenix.LiveView.Rendered.t()
  def action(assigns) do
    if assigns.href || assigns.navigate || assigns.patch do
      ~H"""
      <.link
        href={@href}
        navigate={@navigate}
        patch={@patch}
        class="app-action btn btn-sm"
        data-variant={@variant}
        data-size={@size}
        data-active={to_string(@active == true)}
        data-soft={to_string(@soft)}
        title={@title}
        aria-current={if(@active == true, do: "page")}
        {@rest}
      >
        <span class="app-action-spinner" aria-hidden="true"></span>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button
        type={@type}
        class="app-action btn btn-sm"
        data-variant={@variant}
        data-size={@size}
        data-active={to_string(@active == true)}
        data-soft={to_string(@soft)}
        title={@title}
        aria-pressed={if(is_boolean(@active), do: to_string(@active))}
        {@rest}
      >
        <span class="app-action-spinner" aria-hidden="true"></span>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc "Renders related actions as one joined control."
  slot :inner_block, required: true

  @spec action_group(map()) :: Phoenix.LiveView.Rendered.t()
  def action_group(assigns) do
    ~H"""
    <div class="app-action-group flex gap-2">{render_slot(@inner_block)}</div>
    """
  end

  @doc "Renders a semantic status badge."
  attr :tone, :atom,
    default: :quiet,
    values: [:primary, :info, :success, :warning, :danger, :quiet, :outline]

  attr :size, :atom, default: :sm, values: [:xs, :sm, :md, :lg]
  attr :rest, :global
  slot :inner_block, required: true

  @spec status_badge(map()) :: Phoenix.LiveView.Rendered.t()
  def status_badge(assigns) do
    ~H"""
    <span class="app-badge badge badge-outline" data-tone={@tone} data-size={@size} {@rest}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  @doc "Renders an application notice backed by DaisyUI's alert primitive."
  attr :tone, :atom,
    default: :info,
    values: [:info, :success, :warning, :danger]

  attr :role, :string, default: nil, values: [nil, "alert", "note", "status"]
  attr :rest, :global
  slot :inner_block, required: true

  @spec notice(map()) :: Phoenix.LiveView.Rendered.t()
  def notice(assigns) do
    ~H"""
    <div class="app-alert alert" data-tone={@tone} role={@role} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc "Renders a standard empty collection message."
  slot :inner_block, required: true

  @spec empty_state(map()) :: Phoenix.LiveView.Rendered.t()
  def empty_state(assigns) do
    ~H"""
    <p class="app-empty p-4 text-base-content/60">{render_slot(@inner_block)}</p>
    """
  end

  @doc "Renders a labeled fact within a record or inspector region."
  attr :title, :string, default: nil
  slot :inner_block, required: true

  @spec fact(map()) :: Phoenix.LiveView.Rendered.t()
  def fact(assigns) do
    ~H"""
    <section class="app-fact">
      <h2 :if={@title}>{@title}</h2>
      {render_slot(@inner_block)}
    </section>
    """
  end

  @doc "Renders progressively disclosed supporting or technical detail."
  attr :id, :string, default: nil
  attr :title, :string, required: true
  attr :open, :boolean, default: false
  attr :density, :atom, default: :normal, values: [:normal, :compact, :inline]
  attr :rest, :global
  slot :inner_block, required: true

  @spec disclosure(map()) :: Phoenix.LiveView.Rendered.t()
  def disclosure(assigns) do
    ~H"""
    <details id={@id} class="app-disclosure" data-density={@density} open={@open} {@rest}>
      <summary>{@title}</summary>
      <div data-slot="body">{render_slot(@inner_block)}</div>
    </details>
    """
  end

  @doc "Renders preformatted technical content with optional wrapping."
  attr :id, :string, default: nil
  attr :wrap, :boolean, default: false
  attr :resizable, :boolean, default: false
  attr :rest, :global
  slot :inner_block, required: true

  @spec code_block(map()) :: Phoenix.LiveView.Rendered.t()
  def code_block(assigns) do
    ~H"""
    <pre
      id={@id}
      class="app-code overflow-auto bg-base-200 rounded p-3 text-xs"
      data-wrap={to_string(@wrap)}
      data-resizable={to_string(@resizable)}
      {@rest}
    ><%= render_slot(@inner_block) %></pre>
    """
  end

  attr :field, Phoenix.HTML.FormField, required: true
  attr :type, :string, default: "select"
  attr :label, :string, default: nil
  attr :options, :list, default: []
  attr :size, :atom, default: :sm
  attr :width, :atom, default: :medium

  @spec form_field(map()) :: Phoenix.LiveView.Rendered.t()
  def form_field(assigns) do
    ~H"""
    <label class="app-field">
      <span>{@label}</span>
      <select id={@field.id} name={@field.name} class="select select-bordered">
        {Phoenix.HTML.Form.options_for_select(@options, @field.value)}
      </select>
    </label>
    """
  end
end
