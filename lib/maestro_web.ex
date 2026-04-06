defmodule MaestroWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use MaestroWeb, :controller
      use MaestroWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  @spec static_paths() :: term()
  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  @spec router() :: term()
  def router do
    quote do
      use Phoenix.Router, helpers: false

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  @spec channel() :: term()
  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  @spec controller() :: term()
  def controller do
    quote do
      use Phoenix.Controller, formats: [:html, :json]

      use Gettext, backend: MaestroWeb.Gettext

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  @doc """
  LiveView macro for Maestro pages.

  ## Contract

  Every LiveView page is a thin imperative shell. Domain logic lives in resources
  and facades. The LiveView translates user intent into resource calls.

  ### URL param state (resilience + shareability)

  All meaningful page state MUST live in URL query params. This gives you:
  - **Reconnect resilience** — assigns vanish on disconnect, URL params don't
  - **Shareable links** — users can bookmark and share filtered views

  For Cinder tables: `use Cinder.UrlSync` handles this automatically.
  For custom state: drive from `handle_params`, not `handle_event`.

      # Good: state from URL
      def handle_params(params, _uri, socket) do
        {:noreply, apply_params(socket, socket.assigns.live_action, params)}
      end

      defp apply_params(socket, _action, %{"tab" => tab}), do: assign(socket, :tab, tab)
      defp apply_params(socket, _action, _params), do: socket

      # Bad: state from event only (lost on reconnect)
      def handle_event("switch_tab", %{"tab" => tab}, socket) do
        {:noreply, assign(socket, :tab, tab)}
      end

  ### Mount contract

  - Subscribe to PubSub in mount (guarded by `connected?/1`)
  - Defer expensive queries with `connected?/1` to avoid thundering herd on deploy
  - Set page_title and initial assigns
  """
  @spec live_view() :: term()
  def live_view do
    quote do
      use Phoenix.LiveView

      unquote(html_helpers())

      @before_compile MaestroWeb.LiveViewHelpers
    end
  end

  @spec live_component() :: term()
  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  @spec html() :: term()
  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      # Translation
      use Gettext, backend: MaestroWeb.Gettext

      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components
      import MaestroWeb.CoreComponents

      # Common modules used in templates
      alias Phoenix.LiveView.JS
      alias MaestroWeb.Layouts

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  @spec verified_routes() :: term()
  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: MaestroWeb.Endpoint,
        router: MaestroWeb.Router,
        statics: MaestroWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/live_view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
