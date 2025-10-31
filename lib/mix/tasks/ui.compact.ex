defmodule Mix.Tasks.Ui.Compact do
  @moduledoc """
  Applies maximum information density pattern to UI files.
  
  ## Usage
      mix ui.compact [--check] [--file PATH]
  
  ## Options
    * --check - Only check what would be changed (dry run)
    * --file - Apply to specific file only
  
  ## What it does
  Applies these transformations to LiveView/template files:
  
  1. Layout containers: max-w-* → w-full, px-8 py-12 → px-4 py-2
  2. Text sizes: text-2xl → text-sm, text-xl → text-xs
  3. Component sizes: btn → btn-sm, input → input-sm, select → select-sm
  4. Spacing: mb-4 → mb-2, gap-4 → gap-2, p-6 → p-3
  5. Tables: table-pin-rows → table-xs
  6. Icons: w-5 h-5 → w-3 h-3, w-4 h-4 → w-3 h-3
  7. Card padding: card-body → card-body p-3
  8. Labels: label → label py-0
  9. Remove: shadow-xl → shadow-sm
  10. Preserve: Expandable row patterns (hero-chevron-right, toggle functions)
  
  ## Related Scripts
  
  - `mix ui.add_expandable` - Add expandable rows to tables
  - See agents/docs/ui/INFORMATION_DENSITY.md for full pattern guide
  
  Script is idempotent - safe to run multiple times.
  """
  
  use Mix.Task
  
  @shortdoc "Apply compact UI pattern to files"
  
  @transformations [
    # Layout containers
    {~r/class="max-w-\w+ mx-auto px-8 py-12"/, "class=\"w-full px-4 py-2\""},
    {~r/class="max-w-\w+ mx-auto"/, "class=\"w-full\""},
    
    # Text sizes
    {~r/text-2xl/, "text-sm"},
    {~r/text-xl/, "text-xs"},
    {~r/text-lg/, "text-sm"},
    
    # Component sizes
    {~r/class="btn btn-(?!xs|sm)/, "class=\"btn btn-sm "},
    {~r/class="input input-(?!xs|sm)/, "class=\"input input-sm "},
    {~r/class="select select-(?!xs|sm)/, "class=\"select select-sm "},
    {~r/class="alert alert-(\w+)"/, "class=\"alert alert-\\1 p-2\""},
    
    # Badges
    {~r/badge badge-(?!xs|sm)/, "badge badge-xs "},
    
    # Spacing
    {~r/mb-8/, "mb-2"},
    {~r/mb-6/, "mb-2"},
    {~r/mb-4/, "mb-2"},
    {~r/mt-8/, "mt-2"},
    {~r/mt-6/, "mt-2"},
    {~r/mt-4/, "mt-2"},
    {~r/gap-4/, "gap-2"},
    {~r/p-6/, "p-3"},
    
    # Tables
    {~r/table table-zebra table-pin-rows/, "table table-zebra table-xs"},
    {~r/table table-(?!xs)/, "table table-xs "},
    
    # Icons
    {~r/w-5 h-5/, "w-3 h-3"},
    {~r/w-4 h-4/, "w-3 h-3"},
    
    # Cards
    {~r/class="card-body"/, "class=\"card-body p-3\""},
    {~r/shadow-xl/, "shadow-sm"},
    
    # Labels
    {~r/class="label"(?!\s+py-0)/, "class=\"label py-0\""},
    {~r/class="label-text"/, "class=\"label-text text-xs\""},
    
    # Table cells
    {~r/<td>/, "<td class=\"py-1\">"},
  ]
  
  @impl Mix.Task
  def run(args) do
    {opts, _args} = OptionParser.parse!(args, 
      strict: [check: :boolean, file: :string],
      aliases: [c: :check, f: :file]
    )
    
    check_only = Keyword.get(opts, :check, false)
    specific_file = Keyword.get(opts, :file)
    
    files = if specific_file do
      [specific_file]
    else
      find_ui_files()
    end
    
    Mix.shell().info("Found #{length(files)} UI files to process")
    Mix.shell().info("Mode: #{if check_only, do: "CHECK ONLY", else: "APPLY CHANGES"}")
    Mix.shell().info("")
    
    results = Enum.map(files, fn file ->
      process_file(file, check_only)
    end)
    
    changed = Enum.count(results, & &1.changed?)
    unchanged = Enum.count(results, &(!&1.changed?))
    
    Mix.shell().info("")
    Mix.shell().info("Summary:")
    Mix.shell().info("  #{changed} files changed")
    Mix.shell().info("  #{unchanged} files unchanged")
    
    if check_only and changed > 0 do
      Mix.shell().info("")
      Mix.shell().info("Run without --check to apply changes")
    end
  end
  
  defp find_ui_files do
    patterns = [
      "lib/**/*_live.ex",
      "lib/**/components/*.ex",
      "lib/**/templates/**/*.html.heex",
      "lib/**/layouts/*.html.heex"
    ]
    
    patterns
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.filter(&File.regular?/1)
  end
  
  defp process_file(file, check_only) do
    content = File.read!(file)
    new_content = apply_transformations(content)
    
    changed? = content != new_content
    
    if changed? do
      changes = count_changes(content, new_content)
      Mix.shell().info("#{file}: #{changes} transformations")
      
      unless check_only do
        File.write!(file, new_content)
      end
    end
    
    %{file: file, changed?: changed?}
  end
  
  defp apply_transformations(content) do
    Enum.reduce(@transformations, content, fn {pattern, replacement}, acc ->
      String.replace(acc, pattern, replacement)
    end)
  end
  
  defp count_changes(old, new) do
    old_lines = String.split(old, "\n")
    new_lines = String.split(new, "\n")
    
    Enum.zip(old_lines, new_lines)
    |> Enum.count(fn {old_line, new_line} -> old_line != new_line end)
  end
end
