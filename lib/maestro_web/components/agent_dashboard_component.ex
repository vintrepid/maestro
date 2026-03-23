defmodule MaestroWeb.Components.AgentDashboardComponent do
  @moduledoc """
  Live agent dashboard embedded in every page layout.

  Displays the current agent session, recent requests, changed files,
  and a task input for launching new agent sessions. Subscribes to
  `Maestro.Agents.PubSub` for real-time updates when requests and
  sessions are created or completed.

  ## Public interface

    - `<.live_component module={__MODULE__} id="agent-dashboard" />`

  ## Events handled

    - `run_task` — Starts a new agent session via `mix maestro.agent.run`
    - `open_file` — Opens a file in the editor

  ## PubSub messages

    - `{:agent_request, request}` — New request logged
    - `{:agent_response, request}` — Response logged to existing request
    - `{:session_started, session}` — New session started
    - `{:session_ended, session}` — Session completed or failed
  """

  use MaestroWeb, :live_component

  alias Maestro.Ops.AgentDashboard
  alias Maestro.Agents.PubSub, as: AgentPubSub

  # --- Lifecycle ---

  @impl true
  def mount(socket) do
    {:ok, assign(socket, task_input: "", running: false, subscribed: false, expanded: true)}
  end

  @impl true
  def update(_assigns, socket) do
    socket =
      if !socket.assigns.subscribed do
        AgentPubSub.subscribe()
        assign(socket, subscribed: true)
      else
        socket
      end

    {:ok, load_data(socket)}
  end

  # --- Events ---

  @impl true
  def handle_event("run_task", %{"task_input" => description}, socket) when description != "" do
    Task.start(fn ->
      System.cmd("mix", ["maestro.agent.run", "claude-code", "maestro.agent.session", description],
        stderr_to_stdout: true
      )
    end)

    {:noreply, assign(socket, task_input: "")}
  end

  def handle_event("run_task", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("update_input", %{"task_input" => value}, socket) do
    {:noreply, assign(socket, task_input: value)}
  end

  def handle_event("toggle_expanded", _params, socket) do
    {:noreply, assign(socket, expanded: !socket.assigns.expanded)}
  end

  # --- PubSub handlers ---

  # These arrive via the parent LiveView's process. The parent must
  # forward them with `send_update/2`. See `MaestroWeb.LiveViewHelpers`
  # for the automatic forwarding.

  @impl true
  def handle_async(:refresh, _result, socket) do
    {:noreply, load_data(socket)}
  end

  # Called by parent forwarding PubSub messages
  def refresh(socket) do
    load_data(assign(socket, running: false))
  end

  # --- Render ---

  @impl true
  def render(assigns) do
    ~H"""
    <div class="agent-dashboard" id="agent-dashboard">
      <div class="bg-base-200 border-b border-base-300">
        <div
          class="py-2 px-4 flex items-center gap-3 text-sm cursor-pointer hover:bg-base-300 transition-colors"
          phx-click="toggle_expanded"
          phx-target={@myself}
        >
          <span class={"transition-transform #{if @expanded, do: "rotate-90", else: ""}"}>&#9654;</span>
          <%= if @session do %>
            <span class="badge badge-primary badge-sm">{@agent_name}</span>
            <span class="opacity-70 truncate">{@session.task_description || @summary}</span>
            <span class={"badge badge-sm #{session_status_badge(@session.status)}"}>{@session.status}</span>
          <% else %>
            <span class="badge badge-primary badge-sm">Agent</span>
            <span class="opacity-70 truncate">{@summary}</span>
            <span class={"badge badge-sm #{status_badge(@status)}"}>{@status}</span>
          <% end %>
          <%= if @running do %>
            <span class="loading loading-spinner loading-xs"></span>
          <% end %>
          <span class="badge badge-ghost badge-sm">{length(@files)} files</span>
          <a href="/agents" class="btn btn-ghost btn-xs ml-auto" phx-click={JS.toggle()}>View All</a>
        </div>
        <div class={["px-4 pb-4", !@expanded && "hidden"]}>
          <%!-- Task Input --%>
          <form phx-submit="run_task" phx-target={@myself} class="flex gap-2 mb-3">
            <textarea
              name="task_input"
              placeholder="Describe a task to run..."
              rows="2"
              class="textarea textarea-sm textarea-bordered flex-1 leading-tight"
              phx-change="update_input"
              phx-target={@myself}
              disabled={@running}
            >{@task_input}</textarea>
            <button type="submit" class="btn btn-sm btn-primary self-end" disabled={@running || @task_input == ""}>
              Run
            </button>
          </form>

          <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
            <%!-- Session + Task --%>
            <div>
              <h4 class="font-semibold text-xs uppercase opacity-50 mb-2">Current Session</h4>
              <%= if @session do %>
                <p class="text-sm mb-1">{@session.task_description}</p>
                <p class="text-xs opacity-50">{format_datetime(@session.inserted_at)}</p>
              <% else %>
                <p class="text-sm mb-2">{@summary}</p>
                <p class="text-xs opacity-50">{@session_date}</p>
              <% end %>
              <%= if @pending != [] do %>
                <h4 class="font-semibold text-xs uppercase opacity-50 mt-3 mb-1">Pending</h4>
                <ul class="text-sm space-y-1">
                  <%= for item <- @pending do %>
                    <li class="flex items-center gap-1">
                      <span class="text-warning">*</span>
                      {item}
                    </li>
                  <% end %>
                </ul>
              <% end %>
            </div>

            <%!-- Recent Requests --%>
            <div>
              <h4 class="font-semibold text-xs uppercase opacity-50 mb-2">Recent Activity</h4>
              <%= if @recent_requests == [] do %>
                <p class="text-xs opacity-40">No logged requests yet</p>
              <% else %>
                <div class="space-y-1 max-h-48 overflow-y-auto">
                  <%= for req <- @recent_requests do %>
                    <div class="text-xs p-1 rounded bg-base-100">
                      <span class={"badge badge-xs #{kind_badge(req.kind)}"}>{req.kind}</span>
                      <span class="opacity-70 truncate ml-1">{truncate_text(req.content, 80)}</span>
                      <%= if req.duration_ms do %>
                        <span class="opacity-40 ml-1">{req.duration_ms}ms</span>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>

            <%!-- Changed Files --%>
            <div>
              <h4 class="font-semibold text-xs uppercase opacity-50 mb-2">
                Changed Files ({length(@files)})
              </h4>
              <div class="max-h-48 overflow-y-auto">
                <table class="table table-xs">
                  <tbody>
                    <%= for file <- @files do %>
                      <tr class="hover cursor-pointer" phx-click="open_file" phx-value-path={file.path}>
                        <td>
                          <span class={"badge badge-xs #{file_type_badge(file.type)}"}>
                            {file.type}
                          </span>
                        </td>
                        <td class="font-mono text-xs">{file.path}</td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # --- Data loading ---

  defp load_data(socket) do
    task = AgentDashboard.current_task()
    files = AgentDashboard.all_files()
    active = AgentDashboard.active_session()
    session = active || AgentDashboard.latest_session()
    recent_requests = if session, do: AgentDashboard.recent_requests(session.id, 5), else: []
    agent_name = if session, do: AgentDashboard.agent_name(session.agent_id), else: nil

    assign(socket,
      task: task,
      files: files,
      pending: Map.get(task, "pending", []),
      status: Map.get(task, "status", "idle"),
      summary: Map.get(task, "summary", ""),
      session_date: Map.get(task, "session_date", ""),
      session: session,
      recent_requests: recent_requests,
      agent_name: agent_name,
      running: active != nil
    )
  end

  # --- Badge helpers ---

  defp status_badge("in_progress"), do: "badge-warning"
  defp status_badge("complete"), do: "badge-success"
  defp status_badge("blocked"), do: "badge-error"
  defp status_badge(_), do: "badge-ghost"

  defp session_status_badge("active"), do: "badge-success"
  defp session_status_badge("completed"), do: "badge-ghost"
  defp session_status_badge("failed"), do: "badge-error"
  defp session_status_badge(_), do: "badge-ghost"

  defp kind_badge("user_prompt"), do: "badge-primary"
  defp kind_badge("tool_call"), do: "badge-warning"
  defp kind_badge("tool_result"), do: "badge-info"
  defp kind_badge("agent_response"), do: "badge-success"
  defp kind_badge("system"), do: "badge-ghost"
  defp kind_badge(_), do: "badge-ghost"

  defp file_type_badge(:elixir), do: "badge-primary"
  defp file_type_badge(:heex), do: "badge-secondary"
  defp file_type_badge(:css), do: "badge-accent"
  defp file_type_badge(:js), do: "badge-warning"
  defp file_type_badge(:json), do: "badge-info"
  defp file_type_badge(:markdown), do: "badge-ghost"
  defp file_type_badge(_), do: "badge-ghost"

  # --- Formatting helpers ---

  defp truncate_text(nil, _), do: ""
  defp truncate_text(str, max) when byte_size(str) <= max, do: str
  defp truncate_text(str, max), do: String.slice(str, 0, max) <> "..."

  defp format_datetime(nil), do: ""
  defp format_datetime(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  defp format_datetime(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  defp format_datetime(_), do: ""
end
