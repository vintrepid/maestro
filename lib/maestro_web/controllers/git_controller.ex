defmodule MaestroWeb.GitController do
  use MaestroWeb, :controller

  def info(conn, %{"project_path" => project_path}) do
    git_info = get_git_info(project_path)
    json(conn, git_info)
  end

  def info(conn, _params) do
    git_info = get_git_info(File.cwd!())
    json(conn, git_info)
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
            %{branch: branch, ahead: ahead, behind: behind}
          else
            nil
          end
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.sort_by(fn %{ahead: ahead} -> -(ahead || 0) end)
      _ -> []
    end
  end
end
