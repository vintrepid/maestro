defmodule MaestroWeb.AgentsLive do
  @moduledoc """
  LiveView for the Agents page.

  Thin rendering shell — all domain logic lives in `Maestro.Agents.Facade`.
  """
  use MaestroWeb, :live_view

  import MaestroWeb.Live.Helpers.FileOpener
  alias Maestro.Agents.Facade, as: Agents

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    if connected?(socket), do: Agents.subscribe()

    agents = Agents.list_agents()
    sessions = Agents.list_recent_sessions()
    requests = Agents.list_recent_requests()

    socket =
      socket
      |> assign(:page_title, "Agent Dashboard")
      |> assign(:agents, agents)
      |> assign(:selected_session_id, nil)
      |> assign(:session_capacity, Agents.read_session_capacity())
      |> stream(:sessions, sessions)
      |> stream(:requests, requests)

    {:ok, socket}
  end

  @impl true
  @spec handle_params(map(), String.t(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_params(params, _uri, socket) do
    {:noreply, apply_params(socket, socket.assigns.live_action, params)}
  end

  defp apply_params(socket, _action, %{"session" => session_id}) do
    requests = Agents.list_requests_for_session(session_id)

    socket
    |> assign(:selected_session_id, session_id)
    |> stream(:requests, requests, reset: true)
  end

  defp apply_params(socket, _action, _params), do: socket

  @impl true
  def handle_info({:agent_request, request}, socket) do
    socket =
      stream_insert(socket, :requests, Agents.to_request_row(request), at: 0)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:agent_response, request}, socket) do
    socket =
      stream_insert(socket, :requests, Agents.to_request_row(request))

    {:noreply, socket}
  end

  @impl true
  def handle_info({:session_started, session}, socket) do
    socket =
      stream_insert(socket, :sessions, Agents.to_session_row(session), at: 0)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:session_ended, session}, socket) do
    socket =
      stream_insert(socket, :sessions, Agents.to_session_row(session))

    {:noreply, socket}
  end

  @impl true
  def handle_event("open_file", %{"path" => path}, socket) do
    open_file(path)
    {:noreply, socket}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={assigns[:current_user]}>
      <div class="space-y-4">
        <%!-- Header --%>
        <div class="flex items-center justify-between">
          <h1 class="text-2xl font-bold">Agent Dashboard</h1>
          <div class="flex gap-2">
            <%= if @session_capacity do %>
              <span class="badge badge-lg badge-info" title="Maestro session capacity">
                <.icon name="hero-cpu-chip" class="w-4 h-4 mr-1" />
                {@session_capacity}
              </span>
            <% end %>
            <div class="badge badge-primary badge-lg">{length(@agents)} agents</div>
          </div>
        </div>

        <%!-- Agents Overview --%>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <%= for agent <- @agents do %>
            <div class="card bg-base-200 shadow-sm">
              <div class="card-body p-4">
                <div class="flex items-center gap-2">
                  <span class={["badge badge-sm", agent_type_badge(agent.type)]}>{agent.type}</span>
                  <h3 class="font-semibold">{agent.name}</h3>
                </div>
                <%= if agent.model do %>
                  <p class="text-xs opacity-60 font-mono">{agent.model}</p>
                <% end %>
                <%= if agent.description do %>
                  <p class="text-sm opacity-70">{agent.description}</p>
                <% end %>
              </div>
            </div>
          <% end %>
          <%= if @agents == [] do %>
            <div class="col-span-3 text-center py-8 opacity-50">
              No agents registered yet. Run a task with
              <code class="font-mono">mix maestro.agent.run</code>
              to get started.
            </div>
          <% end %>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-4 gap-4">
          <%!-- Agent Startup Sequence --%>
          <div>
            <MaestroWeb.Components.GuidelinesViewer.guidelines_viewer />
          </div>

          <%!-- Sessions Panel --%>
          <div class="card bg-base-200 shadow-sm">
            <div class="card-body p-4">
              <h2 class="card-title text-lg">Sessions</h2>
              <div class="max-h-96 overflow-y-auto space-y-2" id="sessions" phx-update="stream">
                <div
                  :for={{dom_id, session} <- @streams.sessions}
                  id={dom_id}
                  class={[
                    "p-2 rounded cursor-pointer hover:bg-base-300 transition-colors",
                    session.id == @selected_session_id && "bg-base-300 ring-1 ring-primary"
                  ]}
                  phx-click={JS.patch(~p"/agents?session=#{session.id}")}
                >
                  <div class="flex items-center justify-between">
                    <span class={["badge badge-xs", session_status_badge(session.status)]}>
                      {session.status}
                    </span>
                    <span class="text-xs opacity-50">{format_time(session.inserted_at)}</span>
                  </div>
                  <p class="text-sm mt-1 truncate">{session.task_description || "No description"}</p>
                </div>
              </div>
            </div>
          </div>

          <%!-- Requests/Activity Feed --%>
          <div class="card bg-base-200 shadow-sm lg:col-span-2">

            <div class="card-body p-4">
              <div class="flex items-center justify-between">
                <h2 class="card-title text-lg">
                  <%= if @selected_session_id do %>
                    Session Activity
                  <% else %>
                    Recent Activity
                  <% end %>
                </h2>
                <%= if @selected_session_id do %>
                  <.link patch={~p"/agents"} class="btn btn-ghost btn-xs">
                    Show all
                  </.link>
                <% end %>
              </div>
              <div class="max-h-[600px] overflow-y-auto space-y-1" id="requests" phx-update="stream">
                <div
                  :for={{dom_id, req} <- @streams.requests}
                  id={dom_id}
                  class="p-2 rounded bg-base-100"
                >
                  <div class="flex items-center gap-2 mb-1">
                    <span class={["badge badge-xs", kind_badge(req.kind)]}>{req.kind}</span>
                    <span class="text-xs opacity-50 font-mono">{format_time(req.inserted_at)}</span>
                    <%= if req.duration_ms do %>
                      <span class="text-xs opacity-40">{req.duration_ms}ms</span>
                    <% end %>
                  </div>
                  <div class="text-sm">
                    <p class="whitespace-pre-wrap break-words max-h-32 overflow-hidden">
                      {truncate(req.content, 500)}
                    </p>
                  </div>
                  <%= if req.response do %>
                    <div class="mt-1 pl-3 border-l-2 border-success/30">
                      <p class="text-sm opacity-70 whitespace-pre-wrap break-words max-h-32 overflow-hidden">
                        {truncate(req.response, 500)}
                      </p>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # --- View helpers (badge colors, formatting, truncation) ---

  defp agent_type_badge(:claude_code), do: "badge-primary"
  defp agent_type_badge(:cursor), do: "badge-secondary"
  defp agent_type_badge(:copilot), do: "badge-accent"
  defp agent_type_badge(_), do: "badge-ghost"

  defp session_status_badge(:active), do: "badge-success"
  defp session_status_badge(:completed), do: "badge-ghost"
  defp session_status_badge(:failed), do: "badge-error"
  defp session_status_badge(_), do: "badge-ghost"

  defp kind_badge(:user_prompt), do: "badge-primary"
  defp kind_badge(:tool_call), do: "badge-warning"
  defp kind_badge(:tool_result), do: "badge-info"
  defp kind_badge(:agent_response), do: "badge-success"
  defp kind_badge(:system), do: "badge-ghost"
  defp kind_badge(_), do: "badge-ghost"

  defp format_time(nil), do: ""
  defp format_time(%DateTime{} = dt), do: Calendar.strftime(dt, "%H:%M:%S")
  defp format_time(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%H:%M:%S")
  defp format_time(_), do: ""

  defp truncate(nil, _), do: ""
  defp truncate(str, max) when byte_size(str) <= max, do: str
  defp truncate(str, max), do: String.slice(str, 0, max) <> "..."
end
