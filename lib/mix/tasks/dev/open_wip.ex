defmodule Mix.Tasks.Dev.OpenWip do
  @moduledoc """
  Opens all Work-In-Progress files in VSCodium and can apply code modifications.
  
  Finds files that are:
  - Modified (staged or unstaged)
  - New/untracked
  - Part of current git diff
  
  ## Usage
  
      mix dev.open_wip
      
  Opens files in the appropriate VSCodium window based on project directory.
  
  ## Future: Code Modifications
  
  This task can be extended to:
  - Auto-format changed files
  - Add missing documentation
  - Fix common linting issues
  - Apply project-specific transformations
  """
  use Igniter.Mix.Task

  @shortdoc "Opens WIP files in VSCodium"

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :dev,
      example: "mix dev.open_wip",
      schema: [
        format: :boolean,
        fix_lint: :boolean
      ],
      aliases: [
        f: :format,
        l: :fix_lint
      ]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    project_root = File.cwd!()
    project_name = Path.basename(project_root)
    
    wip_files = get_wip_files()
    
    igniter =
      if Enum.empty?(wip_files) do
        Igniter.add_warning(igniter, "No WIP files found.")
      else
        Igniter.add_notice(igniter, "Opening #{length(wip_files)} WIP files for #{project_name}...")
        open_in_vscodium(wip_files)
        igniter
      end
    
    igniter
  end

  defp get_wip_files do
    staged = get_staged_files()
    unstaged = get_unstaged_files()
    untracked = get_untracked_files()
    branch_files = get_branch_files()
    
    (staged ++ unstaged ++ untracked ++ branch_files)
    |> Enum.uniq()
    |> Enum.filter(&File.exists?/1)
  end

  defp get_staged_files do
    case System.cmd("git", ["diff", "--cached", "--name-only"], stderr_to_stdout: true) do
      {output, 0} -> 
        output
        |> String.split("\n", trim: true)
        |> Enum.map(&String.trim/1)
      _ -> []
    end
  end

  defp get_unstaged_files do
    case System.cmd("git", ["diff", "--name-only"], stderr_to_stdout: true) do
      {output, 0} -> 
        output
        |> String.split("\n", trim: true)
        |> Enum.map(&String.trim/1)
      _ -> []
    end
  end

  defp get_untracked_files do
    case System.cmd("git", ["ls-files", "--others", "--exclude-standard"], stderr_to_stdout: true) do
      {output, 0} -> 
        output
        |> String.split("\n", trim: true)
        |> Enum.map(&String.trim/1)
      _ -> []
    end
  end

  defp get_branch_files do
    case System.cmd("git", ["diff", "--name-only", "master..HEAD"], stderr_to_stdout: true) do
      {output, 0} -> 
        output
        |> String.split("\n", trim: true)
        |> Enum.map(&String.trim/1)
      _ -> []
    end
  end

  defp open_in_vscodium(files) do
    args = ["-a", "VSCodium" | files]
    
    case System.cmd("open", args, stderr_to_stdout: true) do
      {_output, 0} -> 
        :ok
      {error, _} -> 
        IO.warn("Failed to open files: #{error}")
    end
  end
end
