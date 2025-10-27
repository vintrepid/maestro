defmodule MaestroWeb.DashboardLive do
  use MaestroWeb, :live_view
  use LiveTable.LiveResource

  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    theme = FunWithFlags.enabled?(:dark_theme) && FunWithFlags.enabled?(:light_theme)
      |> case do
        true -> "both"
        false -> if FunWithFlags.enabled?(:dark_theme), do: "dark", else: "light"
      end

    socket =
      socket
      |> assign(:page_title, "Projects")
      |> assign(:data_provider, {__MODULE__, :list_projects, []})
      |> assign(:theme, theme)

    {:ok, socket}
  end

  @impl true
  def handle_event("navigate_to_project", %{"slug" => slug}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/projects/#{slug}")}
  end

  @impl true
  def handle_event("set_theme", %{"theme" => theme}, socket) do
    case theme do
      "light" ->
        FunWithFlags.enable(:light_theme)
        FunWithFlags.disable(:dark_theme)

      "dark" ->
        FunWithFlags.enable(:dark_theme)
        FunWithFlags.disable(:light_theme)

      "both" ->
        FunWithFlags.enable(:light_theme)
        FunWithFlags.enable(:dark_theme)
    end

    {:noreply,
     socket
     |> assign(:theme, theme)
     |> push_event("theme-changed", %{theme: theme})}
  end

  def list_projects do
    from(p in "projects",
      select: %{
        id: type(p.id, :string),
        name: p.name,
        slug: p.slug,
        description: p.description,
        status: p.status,
        web_port: p.web_port,
        debugger_port: p.debugger_port,
        github_url: p.github_url
      },
      order_by: [asc: p.web_port]
    )
  end

  def fields do
    [
      name: %{
        label: "Project",
        sortable: true,
        searchable: true,
        renderer: fn _name, %{slug: slug, name: name} = _row ->
          Phoenix.HTML.raw("""
          <a href="/projects/#{slug}" class="link link-primary font-semibold hover:link-hover">
            #{Phoenix.HTML.html_escape(name) |> Phoenix.HTML.safe_to_string()}
          </a>
          """)
        end
      },
      description: %{label: "Description", sortable: false},
      status: %{label: "Status", sortable: true},
      web_port: %{label: "Web Port", sortable: true},
      debugger_port: %{label: "Debugger Port", sortable: false},
      github_url: %{label: "GitHub", sortable: false}
    ]
  end

  def filters, do: []

  def table_options do
    %{
      pin_header: true,
      zebra: true,
      pagination: %{
        default_size: 25
      }
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={assigns[:current_user]}>
      <div class="card bg-base-200">
        <div class="card-body p-0">
          <.live_table
            fields={fields()}
            filters={filters()}
            options={@options}
            streams={@streams}
            table_options={table_options()}
          />
        </div>
      </div>
    </Layouts.app>
    """
  end
end
