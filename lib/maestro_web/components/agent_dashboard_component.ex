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
        Phoenix.PubSub.subscribe(Maestro.PubSub, Maestro.Ops.TaskPubSub.topic())
        assign(socket, subscribed: true)
      else
        socket
      end

    {:ok, load_data(socket)}
  end

  @impl true
  def handle_info({:task_changed, _action, _task}, socket) do
    {:noreply, load_data(socket)}
  end

  # --- Events ---

  @impl true
  def handle_event("start_session", %{"task_input" => description}, socket) when description != "" do
    alias Maestro.Agents.Logger

    {:ok, agent, session} = Logger.start_session("claude-code", description,
      type: :claude_code, model: "claude-opus-4-6"
    )

    Logger.log_request(agent, session, :user_prompt, description)

    {:noreply, assign(socket, task_input: "")}
  end

  def handle_event("start_session", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("complete_session", _params, socket) do
    case AgentDashboard.active_session() do
      nil -> {:noreply, socket}
      session ->
        db_session = Maestro.Repo.get!(Maestro.Agents.Session, session.id)
        Maestro.Agents.Logger.end_session(db_session)
        {:noreply, socket}
    end
  end

  def handle_event("log_milestone", %{"milestone" => milestone}, socket) when milestone != "" do
    case AgentDashboard.active_session() do
      nil -> {:noreply, socket}
      session ->
        agent = Maestro.Repo.get!(Maestro.Agents.Agent, session.agent_id)
        db_session = Maestro.Repo.get!(Maestro.Agents.Session, session.id)
        Maestro.Agents.Logger.log_request(agent, db_session, :agent_response, milestone)
        {:noreply, assign(socket, task_input: "")}
    end
  end

  def handle_event("log_milestone", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("approve_task", _params, socket) do
    if socket.assigns.task do
      task = Maestro.Ops.Task.by_id!(socket.assigns.task.id)
      Maestro.Ops.Task.update(task, %{notes: "Plan approved by user at #{DateTime.utc_now()}"}, authorize?: false)
    end

    {:noreply, socket}
  end

  def handle_event("complete_task", _params, socket) do
    if socket.assigns.task do
      task = Maestro.Ops.Task.by_id!(socket.assigns.task.id)
      Maestro.Ops.Task.mark_complete(task)
    end

    {:noreply, socket}
  end

  def handle_event("update_input", params, socket) do
    value = params["task_input"] || params["milestone"] || ""
    {:noreply, assign(socket, task_input: value)}
  end

  def handle_event("toggle_expanded", _params, socket) do
    new_expanded = !socket.assigns.expanded
    {:noreply, push_event(assign(socket, expanded: new_expanded), "dashboard-state", %{expanded: new_expanded})}
  end

  def handle_event("restore_state", %{"expanded" => expanded}, socket) do
    {:noreply, assign(socket, expanded: expanded)}
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
    <div class="agent-dashboard" id="agent-dashboard" phx-hook="AgentDashboard">
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
          <%!-- Session Controls --%>
          <%= if @running do %>
            <div class="flex gap-2 mb-3">
              <form phx-submit="log_milestone" phx-target={@myself} class="flex gap-2 flex-1">
                <textarea
                  name="milestone"
                  placeholder="Log a milestone..."
                  rows="2"
                  class="textarea textarea-sm textarea-bordered flex-1 leading-tight"
                  phx-change="update_input"
                  phx-target={@myself}
                >{@task_input}</textarea>
                <button type="submit" class="btn btn-sm btn-ghost self-end" disabled={@task_input == ""}>
                  Log
                </button>
              </form>
              <button
                phx-click="complete_session"
                phx-target={@myself}
                class="btn btn-sm btn-success self-end"
              >
                Complete
              </button>
            </div>
          <% else %>
            <form phx-submit="start_session" phx-target={@myself} class="flex gap-2 mb-3">
              <textarea
                name="task_input"
                placeholder="Describe a new task..."
                rows="2"
                class="textarea textarea-sm textarea-bordered flex-1 leading-tight"
                phx-change="update_input"
                phx-target={@myself}
              >{@task_input}</textarea>
              <button type="submit" class="btn btn-sm btn-primary self-end" disabled={@task_input == ""}>
                Start
              </button>
            </form>
          <% end %>

          <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
            <%!-- Current Task --%>
            <div>
              <h4 class="font-semibold text-xs uppercase opacity-50 mb-2">Current Task</h4>
              <%= if @task do %>
                <p class="text-sm font-semibold mb-1">{@task.title}</p>
                <p class="text-xs opacity-50 mb-2">{@session_date}</p>
                <%= if @task.description do %>
                  <div class="prose prose-sm max-w-none compact-prose max-h-48 overflow-y-auto text-xs">
                    {raw(Earmark.as_html!(@task.description))}
                  </div>
                <% end %>
                <%= if @task.status == "in_progress" do %>
                  <div class="flex gap-2 mt-3">
                    <button phx-click="approve_task" phx-target={@myself} class="btn btn-xs btn-success">
                      Approve Plan
                    </button>
                    <button phx-click="complete_task" phx-target={@myself} class="btn btn-xs btn-ghost">
                      Complete
                    </button>
                  </div>
                <% end %>
              <% else %>
                <p class="text-xs opacity-40">No active task</p>
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

    assign(socket,
      task: task,
      files: files,
      pending: [],
      status: if(task, do: to_string(task.status), else: "idle"),
      summary: if(task, do: task.title, else: ""),
      session_date: if(task, do: Calendar.strftime(task.updated_at, "%Y-%m-%d %H:%M"), else: ""),
      session: nil,
      recent_requests: [],
      agent_name: "claude-code",
      running: task != nil and to_string(task.status) == "in_progress" and AgentDashboard.active_session() != nil
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
