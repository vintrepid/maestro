defmodule MaestroWeb.Components.AgentDashboardComponent do
  use MaestroWeb, :html

  alias Maestro.Ops.AgentDashboard

  def agent_dashboard(assigns) do
    task = AgentDashboard.current_task()
    files = AgentDashboard.all_files()
    session = AgentDashboard.active_session() || AgentDashboard.latest_session()

    recent_requests =
      if session, do: AgentDashboard.recent_requests(session.id, 5), else: []

    agent_name = if session, do: AgentDashboard.agent_name(session.agent_id), else: nil

    assigns =
      assigns
      |> assign(:task, task)
      |> assign(:files, files)
      |> assign(:pending, Map.get(task, "pending", []))
      |> assign(:status, Map.get(task, "status", "idle"))
      |> assign(:summary, Map.get(task, "summary", ""))
      |> assign(:session_date, Map.get(task, "session_date", ""))
      |> assign(:session, session)
      |> assign(:recent_requests, recent_requests)
      |> assign(:agent_name, agent_name)

    ~H"""
    <div class="agent-dashboard">
      <div class="collapse collapse-arrow bg-base-200 border-b border-base-300">
        <input type="checkbox" id="agent-dashboard-toggle" />
        <div class="collapse-title py-2 px-4 min-h-0 flex items-center gap-3 text-sm">
          <%= if @session do %>
            <span class="badge badge-primary badge-sm">{@agent_name}</span>
            <span class="opacity-70 truncate">{@session.task_description || @summary}</span>
            <span class={"badge badge-sm #{session_status_badge(@session.status)}"}>{@session.status}</span>
          <% else %>
            <span class="badge badge-primary badge-sm">Agent</span>
            <span class="opacity-70 truncate">{@summary}</span>
            <span class={"badge badge-sm #{status_badge(@status)}"}>{@status}</span>
          <% end %>
          <span class="badge badge-ghost badge-sm">{length(@files)} files</span>
          <a href="/agents" class="btn btn-ghost btn-xs ml-auto">View All</a>
        </div>
        <div class="collapse-content px-4 pb-4">
          <div class="grid grid-cols-1 lg:grid-cols-3 gap-4 mt-2">
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

  defp truncate_text(nil, _), do: ""
  defp truncate_text(str, max) when byte_size(str) <= max, do: str
  defp truncate_text(str, max), do: String.slice(str, 0, max) <> "..."

  defp format_datetime(nil), do: ""
  defp format_datetime(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  defp format_datetime(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  defp format_datetime(_), do: ""

  defp file_type_badge(:elixir), do: "badge-primary"
  defp file_type_badge(:heex), do: "badge-secondary"
  defp file_type_badge(:css), do: "badge-accent"
  defp file_type_badge(:js), do: "badge-warning"
  defp file_type_badge(:json), do: "badge-info"
  defp file_type_badge(:markdown), do: "badge-ghost"
  defp file_type_badge(_), do: "badge-ghost"
end
