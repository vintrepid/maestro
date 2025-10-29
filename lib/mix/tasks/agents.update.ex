defmodule Mix.Tasks.Agents.Update do
  @moduledoc """
  Update agents repository files and commit changes.
  
  This task helps maintain the shared agents directory with proper git workflow.
  
  ## Usage
  
      mix agents.update FILE MESSAGE
      
  ## Examples
  
      mix agents.update bootstrap/GUIDELINES.md "Add new core principle"
      mix agents.update bundles/ui_work.json "Update DaisyUI patterns"
      
  ## What it does
  
  1. Validates file exists in ~/dev/agents
  2. Commits the change with provided message
  3. Pushes to origin/main
  4. Reports success/failure
  """
  
  use Mix.Task
  
  @shortdoc "Update and commit agents repo files"
  
  @agents_dir Path.expand("~/dev/agents")
  
  def run([file, message]) do
    file_path = Path.join(@agents_dir, file)
    
    unless File.exists?(file_path) do
      IO.puts(IO.ANSI.red() <> "✗ File not found: #{file_path}" <> IO.ANSI.reset())
      System.halt(1)
    end
    
    IO.puts("Updating agents repo...")
    IO.puts("  File: #{file}")
    IO.puts("  Message: #{message}")
    
    # Git add
    {_, 0} = System.cmd("git", ["add", file], cd: @agents_dir)
    
    # Git commit
    case System.cmd("git", ["commit", "-m", message], cd: @agents_dir) do
      {output, 0} ->
        IO.puts(IO.ANSI.green() <> "✓ Committed" <> IO.ANSI.reset())
        IO.puts(output)
        
        # Git push
        case System.cmd("git", ["push", "origin", "main"], cd: @agents_dir) do
          {push_output, 0} ->
            IO.puts(IO.ANSI.green() <> "✓ Pushed to origin/main" <> IO.ANSI.reset())
            IO.puts(push_output)
            
          {push_error, _} ->
            IO.puts(IO.ANSI.red() <> "✗ Push failed: #{push_error}" <> IO.ANSI.reset())
            System.halt(1)
        end
        
      {error, _} ->
        IO.puts(IO.ANSI.red() <> "✗ Commit failed: #{error}" <> IO.ANSI.reset())
        System.halt(1)
    end
  end
  
  def run(_) do
    IO.puts("Usage: mix agents.update FILE MESSAGE")
    IO.puts("")
    IO.puts("Examples:")
    IO.puts("  mix agents.update bootstrap/GUIDELINES.md \"Add security guidelines\"")
  end
end
