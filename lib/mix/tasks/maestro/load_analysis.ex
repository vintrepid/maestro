defmodule Mix.Tasks.Maestro.LoadAnalysis do
  use Mix.Task

  @shortdoc "Loads CSS analysis JSON into Maestro database"

  @moduledoc """
  Loads CSS analysis results from a JSON file into Maestro's database.
  
  ## Usage
  
      mix maestro.load_analysis path/to/analysis.json --project maestro
      mix maestro.load_analysis /tmp/calvin_analysis.json --project calvin
  
  ## Options
  
    * `--project` - Project name (required)
  """

  def run(args) do
    Mix.Task.run("app.start")
    
    {opts, [file_path | _], _} = OptionParser.parse(args,
      strict: [project: :string]
    )
    
    project_name = opts[:project] || raise "Project name required: --project <name>"
    
    unless File.exists?(file_path) do
      Mix.shell().error("File not found: #{file_path}")
      exit({:shutdown, 1})
    end
    
    Mix.shell().info("Loading analysis from #{file_path} for project #{project_name}...")
    
    case File.read(file_path) do
      {:ok, json} ->
        case Jason.decode(json) do
          {:ok, data} ->
            load_to_database(data, project_name)
            Mix.shell().info("✅ Analysis loaded successfully!")
            
          {:error, reason} ->
            Mix.shell().error("Failed to parse JSON: #{inspect(reason)}")
            exit({:shutdown, 1})
        end
        
      {:error, reason} ->
        Mix.shell().error("Failed to read file: #{reason}")
        exit({:shutdown, 1})
    end
  end

  defp load_to_database(data, project_name) do
    analyzed_at = parse_datetime(data["analyzed_at"])
    description = data["description"]
    
    entries =
      data["classes"]
      |> Enum.flat_map(fn class_data ->
        Enum.map(class_data["occurrences"], fn occ ->
          %{
            project_name: project_name,
            class_name: class_data["class_name"],
            category: class_data["category"],
            description: description,
            file_path: occ["file_path"],
            line_number: occ["line_number"],
            context: occ["context"],
            analyzed_at: analyzed_at,
            inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
            updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
          }
        end)
      end)
    
    {count, _} = Maestro.Repo.insert_all(Maestro.Analysis.TailwindClassUsage, entries)
    Mix.shell().info("Loaded #{count} class usage records")
  end

  defp parse_datetime(nil), do: DateTime.utc_now() |> DateTime.truncate(:second)
  defp parse_datetime(dt_string) do
    case DateTime.from_iso8601(dt_string) do
      {:ok, dt, _} -> DateTime.truncate(dt, :second)
      _ -> DateTime.utc_now() |> DateTime.truncate(:second)
    end
  end
end
