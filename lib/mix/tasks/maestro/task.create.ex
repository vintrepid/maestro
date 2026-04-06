defmodule Mix.Tasks.Maestro.Task.Create do
  @moduledoc """
  Creates a new Maestro task from the command line.

  Used by Claude Code hooks to automatically log work to the Agent Dashboard.

  ## Usage

      mix maestro.task.create "Fix the spinner bug" --type bug
      mix maestro.task.create "Add search to resources" --type feature --entity-type project --entity-id maestro

  ## Options

    * `--type` — Task type: feature, bug, chore, research (default: chore)
    * `--entity-type` — Entity type (default: project)
    * `--entity-id` — Entity ID (default: maestro)
    * `--status` — Initial status: todo, in_progress (default: in_progress)

  ## Output

  Prints the created task ID to stdout as JSON for hook consumption.
  """

  use Mix.Task

  @shortdoc "Create a new Maestro task"

  @impl true
  @spec run([String.t()]) :: :ok
  def run(args) do
    # Start app without web server — we only need DB access
    Application.put_env(:maestro, MaestroWeb.Endpoint, server: false)
    Mix.Task.run("app.start")

    {opts, positional, _} =
      OptionParser.parse(args,
        strict: [
          type: :string,
          entity_type: :string,
          entity_id: :string,
          status: :string
        ],
        aliases: [t: :type]
      )

    title = Enum.join(positional, " ")

    if title == "" do
      Mix.shell().error("Usage: mix maestro.task.create \"task title\" [--type feature]")
      System.halt(1)
    end

    task_type = String.to_existing_atom(opts[:type] || "other")
    status = String.to_existing_atom(opts[:status] || "in_progress")

    case Maestro.Ops.Task.create(
           %{
             title: title,
             task_type: task_type,
             status: status,
             entity_type: opts[:entity_type] || "project",
             entity_id: opts[:entity_id] || resolve_default_project_id()
           },
           authorize?: false
         ) do
      {:ok, task} ->
        IO.puts(Jason.encode!(%{id: task.id, title: task.title, status: to_string(task.status)}))

      {:error, error} ->
        Mix.shell().error("Failed to create task: #{inspect(error)}")
        System.halt(1)
    end
  end

  defp resolve_default_project_id do
    case Maestro.Ops.get_project_by_slug("maestro") do
      nil -> "maestro"
      project -> to_string(project.id)
    end
  end
end
