defmodule Mix.Tasks.Maestro.Task.Read do
  @moduledoc """
  Read a task's details using Ash.
  
  ## Usage
  
      mix maestro.task.read TASK_ID
      
  ## Examples
  
      mix maestro.task.read 20
      mix maestro.task.read 21
  """
  
  use Mix.Task
  
  @shortdoc "Read a task's details"
  
  def run([task_id]) do
    Mix.Task.run("app.start")
    
    id = String.to_integer(task_id)
    task = Maestro.Ops.Task.by_id!(id)
    
    IO.puts("\n" <> IO.ANSI.cyan() <> "=== Task ##{task.id}: #{task.title} ===" <> IO.ANSI.reset())
    IO.puts(IO.ANSI.yellow() <> "Type:" <> IO.ANSI.reset() <> " #{task.task_type}")
    IO.puts(IO.ANSI.yellow() <> "Status:" <> IO.ANSI.reset() <> " #{task.status}")
    
    if task.entity_type do
      IO.puts(IO.ANSI.yellow() <> "Entity:" <> IO.ANSI.reset() <> " #{task.entity_type} (#{task.entity_id})")
    end
    
    IO.puts("\n" <> IO.ANSI.green() <> "Description:" <> IO.ANSI.reset())
    IO.puts(task.description || "(none)")
    
    if task.notes do
      IO.puts("\n" <> IO.ANSI.green() <> "Notes:" <> IO.ANSI.reset())
      IO.puts(task.notes)
    end
    
    IO.puts("\n" <> IO.ANSI.cyan() <> "===" <> IO.ANSI.reset() <> "\n")
  end
  
  def run(_) do
    IO.puts("Usage: mix maestro.task.read TASK_ID")
  end
end
