defmodule Mix.Tasks.Maestro.Gen.Live do
  @moduledoc """
  Generates a LiveView page with URL param state, Cinder table, and PubSub wiring.

  ## Usage

      mix maestro.gen.live ResourceName

  ## Options

    * `--no-table` — Skip Cinder table (generates a simple page instead)
    * `--no-pubsub` — Skip PubSub subscription wiring

  ## What it generates

    * `lib/maestro_web/live/{resource}_live.ex` — LiveView with handle_params, URL state
    * Route suggestion for `lib/maestro_web/router.ex`

  ## Patterns baked in

    * All page state driven from `handle_params` (URL params = source of truth)
    * Cinder.UrlSync for table filter/sort state
    * PubSub subscription in mount (guarded by `connected?/1`)
    * Thin shell — delegates to resource facade
  """
  use Mix.Task

  @shortdoc "Generate a LiveView page with URL state, optional Cinder table"

  @impl true
  def run(args) do
    {opts, rest, _} =
      OptionParser.parse(args, switches: [table: :boolean, pubsub: :boolean])

    resource_name =
      case rest do
        [name | _] -> name
        [] -> Mix.raise("Usage: mix maestro.gen.live ResourceName [--no-table] [--no-pubsub]")
      end

    with_table? = Keyword.get(opts, :table, true)
    with_pubsub? = Keyword.get(opts, :pubsub, true)

    module_name = Macro.camelize(resource_name)
    snake_name = Macro.underscore(resource_name)
    live_module = "MaestroWeb.#{module_name}Live"
    file_path = "lib/maestro_web/live/#{snake_name}_live.ex"

    if File.exists?(file_path) do
      Mix.raise("File already exists: #{file_path}")
    end

    content =
      if with_table? do
        table_template(live_module, module_name, snake_name, with_pubsub?)
      else
        simple_template(live_module, module_name, snake_name, with_pubsub?)
      end

    File.write!(file_path, content)
    Mix.shell().info("Created #{file_path}")

    Mix.shell().info("""

    Next steps:
      1. Add route to lib/maestro_web/router.ex:

           live "/#{snake_name}", #{module_name}Live, :index

      2. Create facade at lib/maestro/ops/#{snake_name}/facade.ex (if needed)
      3. Implement render/1 template
    """)
  end

  defp table_template(live_module, module_name, snake_name, with_pubsub?) do
    pubsub_mount =
      if with_pubsub?,
        do: "\n    if connected?(socket), do: Maestro.ResourcePubSub.subscribe(\"#{snake_name}\")\n",
        else: ""

    pubsub_handler =
      if with_pubsub? do
        """

          @impl true
          def handle_info({Maestro.ResourcePubSub, _, _, _}, socket) do
            {:noreply, Cinder.Refresh.refresh_table(socket, "#{snake_name}-table")}
          end
        """
      else
        ""
      end

    """
    defmodule #{live_module} do
      @moduledoc \"\"\"
      LiveView for the #{module_name} page.

      Thin rendering shell — all domain logic lives in resources.
      All page state is URL-driven via Cinder.UrlSync.
      \"\"\"
      use MaestroWeb, :live_view
      use Cinder.UrlSync

      @impl true
      def mount(_params, _session, socket) do
    #{pubsub_mount}    {:ok,
         socket
         |> assign(:page_title, "#{module_name}")
         |> assign(:query, Maestro.Ops.#{module_name} |> Ash.Query.sort(inserted_at: :desc))}
      end

      @impl true
      def handle_params(params, uri, socket) do
        socket = Cinder.UrlSync.handle_params(params, uri, socket)
        {:noreply, socket}
      end
    #{pubsub_handler}
      @impl true
      def render(assigns) do
        ~H\"\"\"
        <Layouts.app flash={@flash} current_user={@current_user}>
          <div class="page-section">
            <div class="page-header">
              <h1>#{module_name}</h1>
            </div>

            <Cinder.collection
              id="#{snake_name}-table"
              query={@query}
              url_state={@url_state}
              page_size={25}
              theme="daisy_ui"
            >
              <%!-- Add columns here --%>
            </Cinder.collection>
          </div>
        </Layouts.app>
        \"\"\"
      end
    end
    """
  end

  defp simple_template(live_module, module_name, snake_name, with_pubsub?) do
    pubsub_mount =
      if with_pubsub?,
        do: "\n    if connected?(socket), do: Maestro.ResourcePubSub.subscribe(\"#{snake_name}\")\n",
        else: ""

    pubsub_handler =
      if with_pubsub? do
        """

          @impl true
          def handle_info({Maestro.ResourcePubSub, _, _, _}, socket) do
            {:noreply, load_data(socket)}
          end

          defp load_data(socket) do
            # TODO: load data from resource
            socket
          end
        """
      else
        ""
      end

    """
    defmodule #{live_module} do
      @moduledoc \"\"\"
      LiveView for the #{module_name} page.

      Thin rendering shell — all domain logic lives in resources.
      Page state is URL-driven via handle_params.
      \"\"\"
      use MaestroWeb, :live_view

      @impl true
      def mount(_params, _session, socket) do
    #{pubsub_mount}    {:ok,
         socket
         |> assign(:page_title, "#{module_name}")}
      end

      @impl true
      def handle_params(params, _uri, socket) do
        {:noreply, apply_params(socket, socket.assigns.live_action, params)}
      end

      defp apply_params(socket, _action, _params), do: socket
    #{pubsub_handler}
      @impl true
      def render(assigns) do
        ~H\"\"\"
        <Layouts.app flash={@flash} current_user={@current_user}>
          <div class="page-section">
            <div class="page-header">
              <h1>#{module_name}</h1>
            </div>

            <%!-- Page content here --%>
          </div>
        </Layouts.app>
        \"\"\"
      end
    end
    """
  end
end
