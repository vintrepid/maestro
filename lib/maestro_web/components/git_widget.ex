defmodule MaestroWeb.Components.GitWidget do
  use MaestroWeb, :html

  attr :class, :string, default: nil

  def git_widget(assigns) do
    assigns = assign(assigns, :current_branch, get_current_branch())
    assigns = assign(assigns, :commits_ahead, get_commits_ahead_of_master())
    assigns = assign(assigns, :commits_behind, get_commits_behind_master())
    assigns = assign(assigns, :other_branches, get_other_branches_ahead())

    ~H"""
    <.card class={@class}>
      <div class="flex items-center gap-2">
        <.icon name="hero-code-bracket" class="w-4 h-4 text-info" />
        <span class="text-xs font-mono text-info">
          git: {@current_branch}
          <%= if @commits_ahead do %>
            <span class="badge badge-xs badge-warning ml-1">+{@commits_ahead}</span>
          <% end %>
          <%= if @commits_behind do %>
            <span class="badge badge-xs badge-error ml-1">-{@commits_behind}</span>
          <% end %>
        </span>
      </div>
      <%= if @other_branches != [] do %>
        <div class="mt-2">
          <div class="text-xs text-base-content/60">Other branches:</div>
          <div class="flex flex-wrap gap-1 mt-1">
            <%= for {branch, ahead, behind} <- @other_branches do %>
              <div class="badge badge-sm badge-ghost gap-1">
                <span class="font-mono">{branch}</span>
                <%= if ahead do %>
                  <span class="badge badge-xs badge-warning">+{ahead}</span>
                <% end %>
                <%= if behind do %>
                  <span class="badge badge-xs badge-error">-{behind}</span>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </.card>
    """
  end

  def get_current_branch do
    case System.cmd("git", ["branch", "--show-current"], stderr_to_stdout: true) do
      {branch, 0} -> String.trim(branch)
      _ -> "unknown"
    end
  end

  def get_commits_ahead_of_master do
    case System.cmd("git", ["rev-list", "--count", "master..HEAD"], stderr_to_stdout: true) do
      {count, 0} ->
        count_int = String.trim(count) |> String.to_integer()
        if count_int > 0, do: count_int, else: nil
      _ -> nil
    end
  end

  def get_commits_behind_master do
    case System.cmd("git", ["rev-list", "--count", "HEAD..master"], stderr_to_stdout: true) do
      {count, 0} ->
        count_int = String.trim(count) |> String.to_integer()
        if count_int > 0, do: count_int, else: nil
      _ -> nil
    end
  end

  def get_other_branches_ahead do
    current_branch = get_current_branch()

    case System.cmd("git", ["branch"], stderr_to_stdout: true) do
      {branches_output, 0} ->
        branches_output
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.map(&String.replace_prefix(&1, "* ", ""))
        |> Enum.reject(&(&1 == current_branch))
        |> Enum.map(fn branch ->
          ahead = case System.cmd("git", ["rev-list", "--count", "master..#{branch}"], stderr_to_stdout: true) do
            {count, 0} ->
              count_int = String.trim(count) |> String.to_integer()
              if count_int > 0, do: count_int, else: nil
            _ -> nil
          end

          behind = case System.cmd("git", ["rev-list", "--count", "#{branch}..master"], stderr_to_stdout: true) do
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
