defmodule MaestroWeb.LiveViewHelpers do
  @moduledoc """
  Injected into every LiveView via `@before_compile`.

  Provides catch-all handlers for events and messages that originate
  from shared layout components (agent dashboard, file opener).

  ## Injected callbacks

    - `handle_event("open_file", ...)` — Opens file in editor
    - `handle_info({:agent_request, ...}, ...)` — Refreshes agent dashboard
    - `handle_info({:agent_response, ...}, ...)` — Refreshes agent dashboard
    - `handle_info({:session_started, ...}, ...)` — Refreshes agent dashboard
    - `handle_info({:session_ended, ...}, ...)` — Refreshes agent dashboard
  """

  defmacro __before_compile__(_env) do
    quote do
      # File opener for the agent dashboard's changed files list
      @spec handle_event(any(), map(), Phoenix.LiveView.Socket.t()) :: term()
      def handle_event("open_file", %{"path" => path}, socket) do
        MaestroWeb.Live.Helpers.FileOpener.open_file(path)
        {:noreply, socket}
      end

      # Forward PubSub messages to the agent dashboard LiveComponent
      def handle_info({event, _data}, socket)
          when event in [:agent_request, :agent_response, :session_started, :session_ended] do
        send_update(MaestroWeb.Components.AgentDashboardComponent, id: "agent-dashboard")
        {:noreply, socket}
      end

      # Forward task PubSub messages to the agent dashboard
      @spec handle_info(term(), term()) :: term()
      def handle_info({:task_changed, _action, _task}, socket) do
        send_update(MaestroWeb.Components.AgentDashboardComponent, id: "agent-dashboard")
        {:noreply, socket}
      end
    end
  end
end
