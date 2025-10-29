defmodule Mix.Tasks.Session.Learn do
  @moduledoc """
  End session by extracting learnings and updating guidelines.
  
  This replaces verbose session files with succinct extraction:
  1. Agent describes what they learned (brief!)
  2. Tool extracts key patterns
  3. Updates guidelines automatically
  4. Archives verbose notes
  
  Usage:
    mix session.learn "Always use Ash for data, not browser_eval"
    mix session.learn --file my_notes.md
  """
  
  use Mix.Task
  
  @shortdoc "Extract learnings and update guidelines"
  
  @agents_dir Path.expand("~/dev/agents")
  
  def run(["--file", file_path]) do
    unless File.exists?(file_path) do
      Mix.shell().error("File not found: #{file_path}")
      exit({:shutdown, 1})
    end
    
    content = File.read!(file_path)
    extract_and_update(content)
  end
  
  def run([learning_text]) do
    extract_and_update(learning_text)
  end
  
  def run(_) do
    Mix.shell().error("""
    Usage:
      mix session.learn "Your key learning here"
      mix session.learn --file path/to/notes.md
      
    Be succinct! Focus on:
    - What mistake was made?
    - What's the correct pattern?
    - Why does it matter?
    """)
  end
  
  defp extract_and_update(text) do
    Mix.shell().info("📚 Analyzing learning...")
    
    # Parse the learning
    learning = parse_learning(text)
    
    if learning do
      Mix.shell().info("\n✅ Extracted:")
      Mix.shell().info("   Pattern: #{learning.pattern}")
      Mix.shell().info("   Category: #{learning.category}")
      Mix.shell().info("   Priority: #{learning.priority}")
      
      # Update the appropriate file
      case learning.category do
        :critical -> update_guidelines_critical(learning)
        :database -> update_database_guide(learning)
        :ui -> update_ui_guide(learning)
        :workflow -> update_workflow_guide(learning)
        _ -> Mix.shell().info("   No guideline update needed")
      end
      
      # Archive the learning
      archive_learning(learning, text)
      
      Mix.shell().info("\n✨ Guidelines updated! Future agents will know this.")
    else
      Mix.shell().error("Could not parse learning. Be more specific!")
    end
  end
  
  defp parse_learning(text) do
    # Simple pattern detection
    cond do
      String.contains?(text, ["ash", "Ash", "data", "modify"]) and 
      String.contains?(text, ["browser", "UI", "DOM"]) ->
        %{
          pattern: "Always use Ash for data modifications",
          category: :critical,
          priority: "critical",
          mistake: "Using browser_eval or UI manipulation",
          solution: "Use Ash resources: Resource.update(record, %{field: value})",
          reason: "Browser changes don't persist, Ash validates and saves"
        }
        
      String.contains?(text, ["task", "description", "notes"]) ->
        %{
          pattern: "Task Runner: Description → Work → Notes",
          category: :workflow,
          priority: "critical",
          mistake: "Not documenting completion",
          solution: "Task.update(task, %{notes: completion_report})",
          reason: "Notes field is the response/completion documentation"
        }
        
      String.contains?(text, ["bundle", "load", "minimal"]) ->
        %{
          pattern: "Load only needed bundles",
          category: :workflow,
          priority: "high",
          solution: "Check task requirements, load specific bundles",
          reason: "Saves tokens, faster startup"
        }
        
      true ->
        # Generic extraction
        %{
          pattern: String.slice(text, 0..100),
          category: :general,
          priority: "medium"
        }
    end
  end
  
  defp update_guidelines_critical(learning) do
    path = Path.join([@agents_dir, "bootstrap", "GUIDELINES.md"])
    
    if File.exists?(path) do
      content = File.read!(path)
      
      # Add to Critical Rules section if not already there
      unless String.contains?(content, learning.pattern) do
        rule = """
        
        ### #{learning.pattern}
        
        ❌ **Mistake:** #{learning.mistake}
        
        ✅ **Solution:**
        ```elixir
        #{learning.solution}
        ```
        
        **Why:** #{learning.reason}
        """
        
        updated = String.replace(content, 
          "## Critical Rules\n",
          "## Critical Rules\n#{rule}\n"
        )
        
        File.write!(path, updated)
        Mix.shell().info("   ✅ Updated bootstrap/GUIDELINES.md")
      else
        Mix.shell().info("   ✓ Already in guidelines")
      end
    end
  end
  
  defp update_database_guide(learning) do
    path = Path.join([@agents_dir, "database_work", "PATTERNS.md"])
    append_pattern(path, learning)
  end
  
  defp update_ui_guide(learning) do
    path = Path.join([@agents_dir, "ui_work", "PATTERNS.md"])
    append_pattern(path, learning)
  end
  
  defp update_workflow_guide(learning) do
    path = Path.join([@agents_dir, "maestro", "WORKFLOW_PATTERNS.md"])
    append_pattern(path, learning)
  end
  
  defp append_pattern(path, learning) do
    content = if File.exists?(path), do: File.read!(path), else: "# Patterns\n\n"
    
    unless String.contains?(content, learning.pattern) do
      pattern = """
      
      ## #{learning.pattern}
      
      #{if learning.mistake, do: "**Mistake:** #{learning.mistake}\n", else: ""}
      **Solution:** #{learning.solution}
      
      **Why:** #{learning.reason}
      """
      
      File.write!(path, content <> pattern)
      Mix.shell().info("   ✅ Updated #{Path.basename(path)}")
    end
  end
  
  defp archive_learning(learning, original_text) do
    # Save to sessions directory with timestamp
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601() |> String.replace(":", "-")
    filename = "LEARNING_#{timestamp}.md"
    path = Path.join([@agents_dir, "sessions", filename])
    
    archive = """
    # Learning: #{learning.pattern}
    
    **Category:** #{learning.category}  
    **Priority:** #{learning.priority}  
    **Captured:** #{timestamp}
    
    ## Extracted Pattern
    
    #{inspect(learning, pretty: true)}
    
    ## Original Notes
    
    #{original_text}
    """
    
    File.write!(path, archive)
    Mix.shell().info("   ✅ Archived to sessions/#{filename}")
  end
end
