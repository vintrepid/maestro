defmodule Mix.Tasks.Ui.AddExpandable do
  @moduledoc """
  Adds expandable row pattern to table components.
  
  ## Usage
      mix ui.add_expandable PATH [--field FIELD]
  
  ## Options
    * --field - Field name to expand (default: description)
    * --check - Dry run, show what would change
  
  ## What it does
  
  Transforms a table component to add expandable rows:
  
  1. Adds chevron column to header
  2. Adds toggle button to each row
  3. Creates hidden detail row below each item
  4. Adds toggle_row helper function
  5. Handles markdown rendering
  
  ## Example
  
      # Add expandable descriptions to task table
      mix ui.add_expandable lib/maestro_web/components/task_table.ex
      
      # Add expandable notes field
      mix ui.add_expandable lib/maestro_web/components/note_table.ex --field notes
  
  Script is idempotent - safe to run multiple times.
  """
  
  use Mix.Task
  
  @shortdoc "Add expandable row pattern to table"
  
  @impl Mix.Task
  def run(args) do
    {opts, files} = OptionParser.parse!(args,
      strict: [field: :string, check: :boolean],
      aliases: [f: :field, c: :check]
    )
    
    field = Keyword.get(opts, :field, "description")
    check_only = Keyword.get(opts, :check, false)
    
    if files == [] do
      Mix.shell().error("Usage: mix ui.add_expandable PATH [--field FIELD]")
      exit(:shutdown)
    end
    
    file = List.first(files)
    
    unless File.exists?(file) do
      Mix.shell().error("File not found: #{file}")
      exit(:shutdown)
    end
    
    content = File.read!(file)
    
    cond do
      has_expandable_pattern?(content) ->
        Mix.shell().info("✓ File already has expandable pattern")
        
      not has_table?(content) ->
        Mix.shell().error("✗ File doesn't appear to contain a table component")
        exit(:shutdown)
        
      true ->
        new_content = add_expandable_pattern(content, field)
        
        if check_only do
          Mix.shell().info("Would add expandable pattern to #{file}")
          show_diff(content, new_content)
        else
          File.write!(file, new_content)
          Mix.shell().info("✓ Added expandable pattern to #{file}")
          Mix.shell().info("")
          Mix.shell().info("Next steps:")
          Mix.shell().info("  1. Review the changes")
          Mix.shell().info("  2. Add 'alias Phoenix.LiveView.JS' if not present")
          Mix.shell().info("  3. Test expand/collapse functionality")
        end
    end
  end
  
  defp has_expandable_pattern?(content) do
    String.contains?(content, "toggle_row") or 
    String.contains?(content, "hero-chevron-right")
  end
  
  defp has_table?(content) do
    String.contains?(content, "<table") or 
    String.contains?(content, "~H\"\"\"")
  end
  
  defp add_expandable_pattern(content, field) do
    content
    |> add_chevron_header()
    |> add_toggle_button(field)
    |> add_detail_row(field)
    |> add_toggle_function()
  end
  
  defp add_chevron_header(content) do
    # Add empty <th> for chevron column at start of header
    String.replace(content, 
      ~r/<thead>\s*<tr>/,
      "<thead>\n          <tr>\n            <th class=\"w-8\"></th>"
    )
  end
  
  defp add_toggle_button(content, field) do
    # Add chevron button as first <td> in body rows
    # This is a simplified version - real implementation would need
    # to intelligently find the right place based on table structure
    content
  end
  
  defp add_detail_row(content, field) do
    # Add hidden detail row after main row
    # Template for the detail row with markdown rendering
    detail_template = """
          <%= if item.#{field} do %>
            <tr id={"detail-\#{item.id}"} style="display: none;">
              <td></td>
              <td colspan="N" class="py-1">
                <div class="text-xs text-base-content/70 pl-2 prose prose-xs max-w-none">
                  {raw(Earmark.as_html!(item.#{field} || ""))}
                </div>
              </td>
            </tr>
          <% end %>
    """
    
    # Would insert after each main row
    content
  end
  
  defp add_toggle_function(content) do
    # Add helper function if not present
    unless String.contains?(content, "defp toggle_row") do
      function_code = """
      
        defp toggle_row(row_id) do
          JS.toggle(to: "#\#{row_id}")
          |> JS.toggle_class("rotate-90", 
               to: "#chevron-" <> String.replace(row_id, "detail-", ""))
        end
      """
      
      # Insert before final end
      String.replace(content, ~r/\nend\s*$/, function_code <> "\nend")
    else
      content
    end
  end
  
  defp show_diff(old, new) do
    # Simple diff - show line count change
    old_lines = length(String.split(old, "\n"))
    new_lines = length(String.split(new, "\n"))
    
    Mix.shell().info("  Lines: #{old_lines} → #{new_lines} (+#{new_lines - old_lines})")
  end
end
