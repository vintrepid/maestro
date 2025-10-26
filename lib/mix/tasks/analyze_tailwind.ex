defmodule Mix.Tasks.AnalyzeTailwind do
  use Mix.Task

  @shortdoc "Analyzes Tailwind and DaisyUI class usage across the project"
  
  @moduledoc """
  Scans all .ex and .heex files in the project for Tailwind and DaisyUI classes.
  Extracts class names, locations, and generates usage statistics.
  
  ## Usage
  
      mix analyze_tailwind
      mix analyze_tailwind --output results.json
      mix analyze_tailwind --load-db
      mix analyze_tailwind --load-db --description "After home page optimization"
  """

  def run(args) do
    if "--load-db" in args do
      Mix.Task.run("app.start")
    end
    
    Mix.shell().info("Scanning project for Tailwind/DaisyUI classes...")
    
    files = find_files()
    Mix.shell().info("Found #{length(files)} files to analyze")
    
    class_data = 
      files
      |> Enum.flat_map(&extract_classes_from_file/1)
      |> Enum.group_by(& &1.class_name)
      |> Enum.map(fn {class_name, occurrences} ->
        %{
          class_name: class_name,
          count: length(occurrences),
          category: categorize_class(class_name),
          description: describe_class(class_name),
          occurrences: occurrences
        }
      end)
      |> Enum.sort_by(& &1.count, :desc)
    
    output_results(class_data, args)
    
    if "--load-db" in args do
      description = get_description(args)
      load_to_database(class_data, description)
    end
    
    print_summary(class_data)
  end

  defp get_description(args) do
    idx = Enum.find_index(args, &(&1 == "--description"))
    if idx, do: Enum.at(args, idx + 1), else: nil
  end

  defp find_files do
    Path.wildcard("lib/**/*.{ex,heex}")
  end

  defp extract_classes_from_file(file_path) do
    content = File.read!(file_path)
    
    content
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_number} ->
      extract_classes_from_line(line, file_path, line_number)
    end)
  end

  defp extract_classes_from_line(line, file_path, line_number) do
    class_regex = ~r/class[=:]\s*["{]([^"}]+)["}]/
    
    case Regex.run(class_regex, line, capture: :all_but_first) do
      [class_string] ->
        class_string
        |> clean_class_string()
        |> String.split(~r/\s+/)
        |> Enum.reject(&(&1 == ""))
        |> Enum.map(fn class_name ->
          %{
            class_name: class_name,
            file: file_path,
            line: line_number,
            context: String.trim(line)
          }
        end)
      
      nil ->
        []
    end
  end

  defp clean_class_string(str) do
    str
    |> String.replace(~r/#\{[^}]+\}/, "")
    |> String.replace(~r/\[|\]/, "")
    |> String.replace(",", " ")
    |> String.replace("&&", "")
    |> String.replace("||", "")
  end

  defp categorize_class(class_name) do
    cond do
      String.starts_with?(class_name, "text-") -> "typography"
      String.starts_with?(class_name, "font-") -> "typography"
      String.starts_with?(class_name, "leading-") -> "typography"
      
      class_name in ~w(flex grid block inline inline-block hidden) -> "display"
      String.starts_with?(class_name, "flex-") -> "flexbox"
      String.starts_with?(class_name, "grid-") -> "grid"
      String.starts_with?(class_name, "items-") -> "flexbox"
      String.starts_with?(class_name, "justify-") -> "flexbox"
      
      String.starts_with?(class_name, "w-") -> "sizing"
      String.starts_with?(class_name, "h-") -> "sizing"
      String.starts_with?(class_name, "size-") -> "sizing"
      String.starts_with?(class_name, "max-") -> "sizing"
      String.starts_with?(class_name, "min-") -> "sizing"
      
      class_name in ~w(p-0 p-1 p-2 p-3 p-4 p-5 p-6 p-8 p-10 p-12) or
      String.starts_with?(class_name, "p-") or
      String.starts_with?(class_name, "m-") or
      String.starts_with?(class_name, "px-") or
      String.starts_with?(class_name, "py-") or
      String.starts_with?(class_name, "pt-") or
      String.starts_with?(class_name, "pb-") or
      String.starts_with?(class_name, "pl-") or
      String.starts_with?(class_name, "pr-") or
      String.starts_with?(class_name, "mx-") or
      String.starts_with?(class_name, "my-") or
      String.starts_with?(class_name, "mt-") or
      String.starts_with?(class_name, "mb-") or
      String.starts_with?(class_name, "ml-") or
      String.starts_with?(class_name, "mr-") or
      String.starts_with?(class_name, "gap-") or
      String.starts_with?(class_name, "space-") -> "spacing"
      
      String.starts_with?(class_name, "bg-") -> "background"
      String.starts_with?(class_name, "border-") -> "borders"
      String.starts_with?(class_name, "rounded-") -> "borders"
      class_name in ~w(rounded border) -> "borders"
      
      String.starts_with?(class_name, "shadow-") -> "effects"
      class_name == "shadow" -> "effects"
      String.starts_with?(class_name, "opacity-") -> "effects"
      String.starts_with?(class_name, "transition-") -> "effects"
      
      String.starts_with?(class_name, "absolute") -> "position"
      String.starts_with?(class_name, "relative") -> "position"
      String.starts_with?(class_name, "fixed") -> "position"
      String.starts_with?(class_name, "sticky") -> "position"
      String.starts_with?(class_name, "top-") -> "position"
      String.starts_with?(class_name, "bottom-") -> "position"
      String.starts_with?(class_name, "left-") -> "position"
      String.starts_with?(class_name, "right-") -> "position"
      String.starts_with?(class_name, "z-") -> "position"
      
      String.starts_with?(class_name, "btn") -> "daisyui-component"
      String.starts_with?(class_name, "card") -> "daisyui-component"
      String.starts_with?(class_name, "badge") -> "daisyui-component"
      String.starts_with?(class_name, "alert") -> "daisyui-component"
      String.starts_with?(class_name, "navbar") -> "daisyui-component"
      String.starts_with?(class_name, "menu") -> "daisyui-component"
      String.starts_with?(class_name, "dropdown") -> "daisyui-component"
      String.starts_with?(class_name, "modal") -> "daisyui-component"
      String.starts_with?(class_name, "toast") -> "daisyui-component"
      String.starts_with?(class_name, "table") -> "daisyui-component"
      String.starts_with?(class_name, "input") -> "daisyui-component"
      String.starts_with?(class_name, "select") -> "daisyui-component"
      String.starts_with?(class_name, "textarea") -> "daisyui-component"
      String.starts_with?(class_name, "checkbox") -> "daisyui-component"
      String.starts_with?(class_name, "radio") -> "daisyui-component"
      String.starts_with?(class_name, "toggle") -> "daisyui-component"
      String.starts_with?(class_name, "link") -> "daisyui-component"
      class_name in ~w(label fieldset list) -> "daisyui-component"
      
      String.contains?(class_name, "primary") -> "daisyui-theme"
      String.contains?(class_name, "secondary") -> "daisyui-theme"
      String.contains?(class_name, "accent") -> "daisyui-theme"
      String.contains?(class_name, "neutral") -> "daisyui-theme"
      String.contains?(class_name, "base-") -> "daisyui-theme"
      String.contains?(class_name, "info") -> "daisyui-theme"
      String.contains?(class_name, "success") -> "daisyui-theme"
      String.contains?(class_name, "warning") -> "daisyui-theme"
      String.contains?(class_name, "error") -> "daisyui-theme"
      
      String.starts_with?(class_name, "hover:") -> "interactive-state"
      String.starts_with?(class_name, "focus:") -> "interactive-state"
      String.starts_with?(class_name, "active:") -> "interactive-state"
      
      String.starts_with?(class_name, "sm:") -> "responsive"
      String.starts_with?(class_name, "md:") -> "responsive"
      String.starts_with?(class_name, "lg:") -> "responsive"
      String.starts_with?(class_name, "xl:") -> "responsive"
      
      true -> "other"
    end
  end

  defp describe_class(class_name) do
    case class_name do
      "flex" -> "Creates a flex container"
      "grid" -> "Creates a grid container"
      "container" -> "Constrains width with centered margin"
      "mx-auto" -> "Horizontal auto margin (centers)"
      "shadow-xl" -> "Extra large box shadow"
      "shadow-lg" -> "Large box shadow"
      "rounded" -> "Rounded corners (0.25rem)"
      "rounded-full" -> "Fully rounded (circle/pill)"
      _ -> 
        cond do
          String.starts_with?(class_name, "btn") -> "DaisyUI button component"
          String.starts_with?(class_name, "card") -> "DaisyUI card component"
          String.starts_with?(class_name, "badge") -> "DaisyUI badge component"
          String.starts_with?(class_name, "w-") -> "Width utility"
          String.starts_with?(class_name, "h-") -> "Height utility"
          String.starts_with?(class_name, "p-") -> "Padding utility"
          String.starts_with?(class_name, "m-") -> "Margin utility"
          String.starts_with?(class_name, "text-") -> "Text/typography utility"
          String.starts_with?(class_name, "bg-") -> "Background utility"
          true -> class_name
        end
    end
  end

  defp output_results(class_data, args) do
    if "--output" in args do
      idx = Enum.find_index(args, &(&1 == "--output"))
      filename = Enum.at(args, idx + 1, "tailwind_analysis.json")
      
      json_data = Jason.encode!(class_data, pretty: true)
      File.write!(filename, json_data)
      Mix.shell().info("\nResults written to #{filename}")
    end
  end

  defp load_to_database(class_data, run_description) do
    Mix.shell().info("\nLoading data to database...")
    
    analyzed_at = DateTime.utc_now() |> DateTime.truncate(:second)
    Mix.shell().info("Analysis timestamp: #{analyzed_at}")
    if run_description, do: Mix.shell().info("Description: #{run_description}")
    
    entries = 
      class_data
      |> Enum.flat_map(fn %{class_name: class_name, category: category, description: _class_description, occurrences: occurrences} ->
        Enum.map(occurrences, fn occ ->
          %{
            class_name: class_name,
            category: category,
            description: run_description,
            file_path: occ.file,
            line_number: occ.line,
            context: occ.context,
            analyzed_at: analyzed_at,
            inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
            updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
          }
        end)
      end)
    
    {count, _} = Maestro.Repo.insert_all(Maestro.Analysis.TailwindClassUsage, entries)
    Mix.shell().info("Loaded #{count} class usage records to database")
  end

  defp print_summary(class_data) do
    total_classes = length(class_data)
    total_occurrences = Enum.sum(Enum.map(class_data, & &1.count))
    
    Mix.shell().info("\n=== Summary ===")
    Mix.shell().info("Unique classes: #{total_classes}")
    Mix.shell().info("Total occurrences: #{total_occurrences}")
    
    Mix.shell().info("\n=== Top 20 Most Used Classes ===")
    class_data
    |> Enum.take(20)
    |> Enum.each(fn %{class_name: name, count: count, category: cat} ->
      Mix.shell().info("#{String.pad_trailing(name, 30)} #{count} times (#{cat})")
    end)
    
    Mix.shell().info("\n=== By Category ===")
    class_data
    |> Enum.group_by(& &1.category)
    |> Enum.map(fn {category, classes} ->
      {category, length(classes), Enum.sum(Enum.map(classes, & &1.count))}
    end)
    |> Enum.sort_by(fn {_cat, _unique, total} -> total end, :desc)
    |> Enum.each(fn {category, unique_count, total_count} ->
      Mix.shell().info("#{String.pad_trailing(category, 20)} #{unique_count} unique, #{total_count} total")
    end)
  end
end
