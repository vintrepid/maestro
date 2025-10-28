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
  def handle_event("delete_project", %{"id" => id}, socket) do
    project = Maestro.Repo.get!(Maestro.Ops.Project, id)
    
    case Maestro.Ops.Project.destroy(project) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Project deleted successfully")
         |> push_navigate(to: ~p"/projects")}
      
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete project")}
    end
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
      order_by: [desc: p.updated_at]
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
      status: %{
        label: "Status",
        sortable: true,
        renderer: fn status, _row ->
          badge_class = case status do
            s when s in [:running, "running"] -> "badge-success"
            s when s in [:stopped, "stopped"] -> "badge-ghost"
            _ -> "badge-ghost"
          end
          
          Phoenix.HTML.raw("""
          <span class="badge badge-sm #{badge_class}">
            #{Phoenix.HTML.html_escape(to_string(status)) |> Phoenix.HTML.safe_to_string()}
          </span>
          """)
        end
      },
      web_port: %{label: "Web Port", sortable: true},
      debugger_port: %{label: "Debugger Port", sortable: false},
      github_url: %{
        label: "",
        sortable: false,
        renderer: fn github_url, %{id: id} = _row ->
          buttons = if github_url do
            """
            <a href="#{github_url}" target="_blank" rel="noopener noreferrer" class="btn btn-ghost btn-xs" title="#{github_url}">
              <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path fill-rule="evenodd" d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z" clip-rule="evenodd" />
              </svg>
            </a>
            """
          else
            ""
          end
          
          delete_button = """
          <button
            phx-click="delete_project"
            phx-value-id="#{id}"
            data-confirm="Are you sure you want to delete this project?"
            class="btn btn-ghost btn-xs text-error hover:bg-error hover:text-error-content"
            title="Delete project"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
            </svg>
          </button>
          """
          
          Phoenix.HTML.raw("""
          <div class="flex gap-1">
            #{buttons}
            #{delete_button}
          </div>
          """)
        end
      }
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
