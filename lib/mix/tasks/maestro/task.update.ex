defmodule Mix.Tasks.Maestro.Task.Update do
  @moduledoc """
  Update a task's fields using Ash.
  
  ## Usage
  
      mix maestro.task.update TASK_ID FIELD VALUE
      
  ## Examples
  
      mix maestro.task.update 20 status in_progress
      mix maestro.task.update 21 notes "## Completion\\n\\nDone!"
      
  ## Supported Fields
  
  - title
  - description
  - notes
  - status (todo, in_progress, done, blocked)
  - task_type (feature, bug, refactor, documentation, other)
  """
  
  use Mix.Task
  
  @shortdoc "Update a task field"
  
  def run([task_id, field, value]) do
    Mix.Task.run("app.start")
    
    id = String.to_integer(task_id)
    task = Maestro.Ops.Task.by_id!(id)
    
    field_atom = String.to_atom(field)
    
    # Convert value if needed
    actual_value = case field_atom do
      :status -> String.to_atom(value)
      :task_type -> String.to_atom(value)
      _ -> value
    end
    
    case Maestro.Ops.Task.update(task, %{field_atom => actual_value}) do
      {:ok, updated_task} ->
        IO.puts(IO.ANSI.green() <> "✓ Task ##{id} updated: #{field} = #{inspect(actual_value)}" <> IO.ANSI.reset())
        
      {:error, error} ->
        IO.puts(IO.ANSI.red() <> "✗ Failed to update task: #{inspect(error)}" <> IO.ANSI.reset())
    end
  end
  
  def run(_) do
    IO.puts("Usage: mix maestro.task.update TASK_ID FIELD VALUE")
    IO.puts("")
    IO.puts("Examples:")
    IO.puts("  mix maestro.task.update 20 status done")
    IO.puts("  mix maestro.task.update 21 notes \"Completion report here\"")
  end
end
