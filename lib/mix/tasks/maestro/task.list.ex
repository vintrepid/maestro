defmodule Mix.Tasks.Maestro.Task.List do
  @moduledoc """
  List tasks with optional filtering.
  
  ## Usage
  
      mix maestro.task.list [OPTIONS]
      
  ## Options
  
      --status STATUS     Filter by status (todo, in_progress, done, blocked)
      --type TYPE         Filter by type (feature, bug, refactor, documentation, other)
      --project PROJECT   Filter by project name
      --subtasks TASK_ID  Show subtasks of given task
      --limit N           Limit results (default: 20)
      
  ## Examples
  
      mix maestro.task.list
      mix maestro.task.list --status todo
      mix maestro.task.list --type feature --limit 10
      mix maestro.task.list --subtasks 20
  """
  
  use Mix.Task
  import Ecto.Query
  
  @shortdoc "List tasks"
  
  def run(args) do
    Mix.Task.run("app.start")
    
    {opts, _, _} = OptionParser.parse(args, 
      switches: [status: :string, type: :string, project: :string, subtasks: :integer, limit: :integer],
      aliases: [s: :status, t: :type, p: :project, l: :limit]
    )
    
    query = from t in Maestro.Ops.Task,
      order_by: [desc: t.inserted_at]
    
    query = if opts[:status] do
      status = String.to_atom(opts[:status])
      from t in query, where: t.status == ^status
    else
      query
    end
    
    query = if opts[:type] do
      type = String.to_atom(opts[:type])
      from t in query, where: t.task_type == ^type
    else
      query
    end
    
    query = if opts[:subtasks] do
      parent_id = to_string(opts[:subtasks])
      from t in query, where: t.entity_type == "Task" and t.entity_id == ^parent_id
    else
      query
    end
    
    limit = opts[:limit] || 20
    query = from t in query, limit: ^limit
    
    tasks = Maestro.Repo.all(query)
    
    if Enum.empty?(tasks) do
      IO.puts("No tasks found.")
    else
      IO.puts("\n" <> IO.ANSI.cyan() <> "Tasks:" <> IO.ANSI.reset())
      IO.puts(String.duplicate("=", 80))
      
      for task <- tasks do
        status_color = case task.status do
          :done -> IO.ANSI.green()
          :in_progress -> IO.ANSI.yellow()
          :blocked -> IO.ANSI.red()
          _ -> IO.ANSI.white()
        end
        
        IO.puts([
          status_color,
          String.pad_trailing("  ##{task.id}", 8),
          IO.ANSI.reset(),
          String.pad_trailing(to_string(task.status), 15),
          task.title
        ])
      end
      
      IO.puts(String.duplicate("=", 80))
      IO.puts("Total: #{length(tasks)} task(s)\n")
    end
  end
end
