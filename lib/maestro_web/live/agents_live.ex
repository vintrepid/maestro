defmodule MaestroWeb.AgentsLive do
  use MaestroWeb, :live_view

  alias Maestro.Agents.PubSub, as: AgentPubSub

  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: AgentPubSub.subscribe()

    agents = list_agents()
    sessions = list_recent_sessions()
    requests = list_recent_requests()

    socket =
      socket
      |> assign(:page_title, "Agent Dashboard")
      |> assign(:agents, agents)
      |> assign(:selected_session_id, nil)
      |> stream(:sessions, sessions)
      |> stream(:requests, requests)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_params(socket, socket.assigns.live_action, params)}
  end

  defp apply_params(socket, _action, %{"session" => session_id}) do
    requests = list_requests_for_session(session_id)

    socket
    |> assign(:selected_session_id, session_id)
    |> stream(:requests, requests, reset: true)
  end

  defp apply_params(socket, _action, _params), do: socket

  @impl true
  def handle_info({:agent_request, request}, socket) do
    socket =
      socket
      |> stream_insert(:requests, to_request_row(request), at: 0)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:agent_response, request}, socket) do
    socket =
      socket
      |> stream_insert(:requests, to_request_row(request))

    {:noreply, socket}
  end

  @impl true
  def handle_info({:session_started, session}, socket) do
    socket =
      socket
      |> stream_insert(:sessions, to_session_row(session), at: 0)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:session_ended, session}, socket) do
    socket =
      socket
      |> stream_insert(:sessions, to_session_row(session))

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={assigns[:current_user]}>
      <div class="space-y-4">
        <%!-- Header --%>
        <div class="flex items-center justify-between">
          <h1 class="text-2xl font-bold">Agent Dashboard</h1>
          <div class="flex gap-2">
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
              No agents registered yet. Run a task with <code class="font-mono">mix maestro.agent.run</code> to get started.
            </div>
          <% end %>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
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
                    <span class={["badge badge-xs", session_status_badge(session.status)]}>{session.status}</span>
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
                    <p class="whitespace-pre-wrap break-words max-h-32 overflow-hidden">{truncate(req.content, 500)}</p>
                  </div>
                  <%= if req.response do %>
                    <div class="mt-1 pl-3 border-l-2 border-success/30">
                      <p class="text-sm opacity-70 whitespace-pre-wrap break-words max-h-32 overflow-hidden">{truncate(req.response, 500)}</p>
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

  # --- Data fetching ---

  defp list_agents do
    Maestro.Repo.all(from a in "agents",
      select: %{
        id: type(a.id, :string),
        name: a.name,
        type: a.type,
        model: a.model,
        description: a.description
      },
      order_by: [asc: a.name]
    )
    |> Enum.map(fn a -> %{a | type: String.to_existing_atom(a.type)} end)
  end

  defp list_recent_sessions do
    Maestro.Repo.all(from s in "agent_sessions",
      select: %{
        id: type(s.id, :string),
        task_description: s.task_description,
        status: s.status,
        inserted_at: s.inserted_at,
        ended_at: s.ended_at
      },
      order_by: [desc: s.inserted_at],
      limit: 50
    )
    |> Enum.map(fn s -> %{s | status: String.to_existing_atom(s.status)} end)
  end

  defp list_recent_requests do
    Maestro.Repo.all(from r in "agent_requests",
      select: %{
        id: type(r.id, :string),
        kind: r.kind,
        content: r.content,
        response: r.response,
        duration_ms: r.duration_ms,
        inserted_at: r.inserted_at,
        responded_at: r.responded_at,
        metadata: r.metadata
      },
      order_by: [desc: r.inserted_at],
      limit: 50
    )
    |> Enum.map(fn r -> %{r | kind: String.to_existing_atom(r.kind)} end)
  end

  defp list_requests_for_session(session_id) do
    Maestro.Repo.all(from r in "agent_requests",
      where: r.session_id == ^session_id,
      select: %{
        id: type(r.id, :string),
        kind: r.kind,
        content: r.content,
        response: r.response,
        duration_ms: r.duration_ms,
        inserted_at: r.inserted_at,
        responded_at: r.responded_at,
        metadata: r.metadata
      },
      order_by: [desc: r.inserted_at]
    )
    |> Enum.map(fn r -> %{r | kind: String.to_existing_atom(r.kind)} end)
  end

  # --- Row converters for PubSub messages ---

  defp to_request_row(request) do
    %{
      id: to_string(request.id),
      kind: request.kind,
      content: request.content,
      response: request.response,
      duration_ms: request.duration_ms,
      inserted_at: request.inserted_at,
      responded_at: request.responded_at,
      metadata: request.metadata || %{}
    }
  end

  defp to_session_row(session) do
    %{
      id: to_string(session.id),
      task_description: session.task_description,
      status: session.status,
      inserted_at: session.inserted_at,
      ended_at: session.ended_at
    }
  end

  # --- Helpers ---

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
