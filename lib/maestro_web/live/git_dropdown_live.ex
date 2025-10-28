defmodule MaestroWeb.GitDropdownLive do
  use MaestroWeb, :live_component

  def mount(socket) do
    {:ok, assign(socket,
      loaded: false,
      current_branch: nil,
      commits_ahead: nil,
      commits_behind: nil,
      other_branches: [],
      project_path: nil
    )}
  end

  def update(assigns, socket) do
    project_path = Map.get(assigns, :project_path)
    {:ok, assign(socket, project_path: project_path)}
  end

  def render(assigns) do
    ~H"""
    <div class="dropdown dropdown-end">
      <div
        tabindex="0"
        role="button"
        class="btn btn-ghost btn-sm gap-2"
        phx-click="load_git_info"
        phx-target={@myself}
      >
        <.icon name="hero-code-bracket" class="w-4 h-4" />
        <%= if @loaded do %>
          <span class="font-mono text-xs">{@current_branch}</span>
          <%= if @commits_ahead do %>
            <span class="badge badge-xs badge-warning">+{@commits_ahead}</span>
          <% end %>
          <%= if @commits_behind do %>
            <span class="badge badge-xs badge-error">-{@commits_behind}</span>
          <% end %>
        <% else %>
          <span class="font-mono text-xs">git</span>
        <% end %>
      </div>
      <%= if @loaded do %>
        <ul tabindex="0" class="dropdown-content z-[1] menu p-2 shadow-lg bg-base-100 rounded-box w-64">
          <li class="menu-title">Current Branch</li>
          <li class="px-4 py-2">
            <span class="font-mono text-sm">{@current_branch}</span>
          </li>
          <%= if @other_branches != [] do %>
            <li class="menu-title mt-2">Other Branches</li>
            <%= for {branch, ahead, behind} <- @other_branches do %>
              <li>
                <div class="flex items-center justify-between">
                  <span class="font-mono text-xs">{branch}</span>
                  <div class="flex gap-1">
                    <%= if ahead do %>
                      <span class="badge badge-xs badge-warning">+{ahead}</span>
                    <% end %>
                    <%= if behind do %>
                      <span class="badge badge-xs badge-error">-{behind}</span>
                    <% end %>
                  </div>
                </div>
              </li>
            <% end %>
          <% end %>
        </ul>
      <% end %>
    </div>
    """
  end

  def handle_event("load_git_info", _params, socket) do
    project_path = socket.assigns.project_path
    
    git_info = if project_path do
      get_git_info(project_path)
    else
      get_git_info(File.cwd!())
    end

    {:noreply, assign(socket, Map.merge(git_info, %{loaded: true}))}
  end

  defp get_git_info(project_path) do
    current_branch = get_current_branch(project_path)
    commits_ahead = get_commits_ahead_of_master(project_path)
    commits_behind = get_commits_behind_master(project_path)
    other_branches = get_other_branches_ahead(project_path, current_branch)

    %{
      current_branch: current_branch,
      commits_ahead: commits_ahead,
      commits_behind: commits_behind,
      other_branches: other_branches
    }
  end

  defp get_current_branch(project_path) do
    case System.cmd("git", ["branch", "--show-current"], stderr_to_stdout: true, cd: project_path) do
      {branch, 0} -> String.trim(branch)
      _ -> "unknown"
    end
  end

  defp get_commits_ahead_of_master(project_path) do
    case System.cmd("git", ["rev-list", "--count", "master..HEAD"], stderr_to_stdout: true, cd: project_path) do
      {count, 0} ->
        count_int = String.trim(count) |> String.to_integer()
        if count_int > 0, do: count_int, else: nil
      _ -> nil
    end
  end

  defp get_commits_behind_master(project_path) do
    case System.cmd("git", ["rev-list", "--count", "HEAD..master"], stderr_to_stdout: true, cd: project_path) do
      {count, 0} ->
        count_int = String.trim(count) |> String.to_integer()
        if count_int > 0, do: count_int, else: nil
      _ -> nil
    end
  end

  defp get_other_branches_ahead(project_path, current_branch) do
    case System.cmd("git", ["branch"], stderr_to_stdout: true, cd: project_path) do
      {branches_output, 0} ->
        branches_output
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.map(&String.replace_prefix(&1, "* ", ""))
        |> Enum.reject(&(&1 == current_branch))
        |> Enum.map(fn branch ->
          ahead = case System.cmd("git", ["rev-list", "--count", "master..#{branch}"], stderr_to_stdout: true, cd: project_path) do
            {count, 0} ->
              count_int = String.trim(count) |> String.to_integer()
              if count_int > 0, do: count_int, else: nil
            _ -> nil
          end

          behind = case System.cmd("git", ["rev-list", "--count", "#{branch}..master"], stderr_to_stdout: true, cd: project_path) do
            {count, 0} ->
              count_int = String.trim(count) |> String.to_integer()
              if count_int > 0, do: count_int, else: nil
            _ -> nil
          end

          if ahead || behind do
            {branch, ahead, behind}
          else
            nil
          end
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.sort_by(fn {_branch, ahead, _behind} -> -(ahead || 0) end)
      _ -> []
    end
  end
end
