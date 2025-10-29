defmodule Mix.Tasks.Bundle.Extract do
  @moduledoc """
  Extract learnings from a session bundle and integrate them into agents directory.
  
  This reads the consolidated learnings from a bundle JSON and:
  1. Updates relevant guideline files (bootstrap/GUIDELINES.md, etc.)
  2. Creates focused guides for specific patterns
  3. Updates bundle JSONs with new rules
  
  Usage:
    mix bundle.extract sessions
  """
  
  use Mix.Task
  
  @shortdoc "Extract learnings from bundle into agents directory"
  
  @agents_dir Path.expand("~/dev/agents")
  
  def run([bundle_name]) do
    bundle_path = Path.join([@agents_dir, "bundles", "#{bundle_name}.json"])
    
    unless File.exists?(bundle_path) do
      Mix.shell().error("Bundle not found: #{bundle_path}")
      exit({:shutdown, 1})
    end
    
    bundle = bundle_path |> File.read!() |> Jason.decode!()
    learnings = Map.get(bundle, "learnings", [])
    
    Mix.shell().info("📚 Extracting #{length(learnings)} learnings from #{bundle_name} bundle...")
    
    Enum.each(learnings, fn learning ->
      extract_learning(learning, bundle_name)
    end)
    
    Mix.shell().info("\n✨ Extraction complete! Review changes with: git diff")
  end
  
  def run(_) do
    Mix.shell().error("Usage: mix bundle.extract <bundle_name>")
  end
  
  defp extract_learning(learning, _bundle_name) do
    id = learning["id"]
    title = learning["title"]
    priority = learning["priority"]
    applies_to = learning["applies_to"] || []
    
    Mix.shell().info("\n📝 Processing: #{title} (#{priority})")
    
    # 1. Update bootstrap/GUIDELINES.md for critical learnings
    if priority == "critical" do
      update_guidelines(learning)
    end
    
    # 2. Create or update specific guides
    Enum.each(applies_to, fn category ->
      case category do
        "database_work" -> update_database_work(learning)
        "ui_work" -> update_ui_work(learning)
        "maestro" -> update_maestro_guides(learning)
        "task_execution" -> update_task_execution(learning)
        _ -> :ok
      end
    end)
    
    # 3. Update relevant bundle JSONs
    update_bundle_rules(learning, applies_to)
  end
  
  defp update_guidelines(learning) do
    guidelines_path = Path.join([@agents_dir, "bootstrap", "GUIDELINES.md"])
    
    unless File.exists?(guidelines_path) do
      Mix.shell().info("  ⚠️  GUIDELINES.md not found")
      :ok
    else
    
    content = File.read!(guidelines_path)
    
    # Check if already exists
    if String.contains?(content, learning["id"]) do
      Mix.shell().info("  ✓ Already in GUIDELINES.md")
    else
      # Add to Critical Rules section
      rule_entry = """
      
      ### #{learning["title"]}
      
      #{learning["problem"]}
      
      **Solution:**
      ```elixir
      #{learning["code_example"]}
      ```
      
      **Why:**
      #{Enum.map_join(learning["why_it_matters"] || [], "\n", fn reason -> "- #{reason}" end)}
      """
      
      # Insert after ## Critical Rules
      updated = String.replace(content, 
        "## Critical Rules\n",
        "## Critical Rules\n#{rule_entry}\n"
      )
      
      File.write!(guidelines_path, updated)
      Mix.shell().info("  ✅ Added to bootstrap/GUIDELINES.md")
    end
  end
  end
  
  defp update_database_work(learning) do
    guide_path = Path.join([@agents_dir, "database_work", "#{learning["id"]}.md"])
    
    guide_content = """
    # #{learning["title"]}
    
    **Priority:** #{learning["priority"]}  
    **Source:** #{learning["source"]}
    
    ## The Problem
    
    #{learning["problem"]}
    
    ## The Mistake
    
    #{learning["mistake"]}
    
    ## The Solution
    
    ```elixir
    #{learning["code_example"]}
    ```
    
    ## Why This Matters
    
    #{Enum.map_join(learning["why_it_matters"] || [], "\n", fn reason -> "- #{reason}" end)}
    
    ## When to Apply
    
    #{Enum.map_join(learning["applies_to"] || [], "\n", fn category -> "- #{category}" end)}
    
    ---
    *Extracted from: #{learning["source"]}*
    """
    
    File.write!(guide_path, guide_content)
    Mix.shell().info("  ✅ Created database_work/#{learning["id"]}.md")
  end
  
  defp update_ui_work(learning) do
    # Similar to database_work
    guide_path = Path.join([@agents_dir, "ui_work", "#{learning["id"]}.md"])
    
    guide_content = """
    # #{learning["title"]}
    
    **Priority:** #{learning["priority"]}
    
    #{if learning["problem"], do: "## Problem\n\n#{learning["problem"]}\n", else: ""}
    #{if learning["pattern"], do: "## Pattern\n\n#{learning["pattern"]}\n", else: ""}
    #{if learning["code_example"], do: "## Example\n\n```elixir\n#{learning["code_example"]}\n```\n", else: ""}
    
    ---
    *From: #{learning["source"]}*
    """
    
    File.write!(guide_path, guide_content)
    Mix.shell().info("  ✅ Created ui_work/#{learning["id"]}.md")
  end
  
  defp update_maestro_guides(learning) do
    # Update maestro-specific documentation
    guide_path = Path.join([@agents_dir, "maestro", "#{learning["id"]}.md"])
    
    guide_content = """
    # #{learning["title"]}
    
    #{if learning["pattern"], do: learning["pattern"], else: learning["problem"]}
    
    #{if learning["code_example"], do: "```elixir\n#{learning["code_example"]}\n```", else: ""}
    
    #{if learning["completion_checklist"] do
      "## Checklist\n\n" <> Enum.map_join(learning["completion_checklist"], "\n", fn item -> "- [ ] #{item}" end)
    else
      ""
    end}
    """
    
    File.write!(guide_path, guide_content)
    Mix.shell().info("  ✅ Created maestro/#{learning["id"]}.md")
  end
  
  defp update_task_execution(learning) do
    # Add to maestro task execution guides
    update_maestro_guides(learning)
  end
  
  defp update_bundle_rules(learning, applies_to) do
    # Update relevant bundle JSONs with extracted rules
    Enum.each(applies_to, fn category ->
      bundle_file = case category do
        "database_work" -> "database_work.json"
        "ui_work" -> "ui_work.json"
        "maestro" -> "maestro.json"
        _ -> nil
      end
      
      if bundle_file do
        bundle_path = Path.join([@agents_dir, "bundles", bundle_file])
        
        if File.exists?(bundle_path) do
          bundle = bundle_path |> File.read!() |> Jason.decode!()
          
          rules = Map.get(bundle, "rules", [])
          
          # Check if rule already exists
          unless Enum.any?(rules, fn r -> r["id"] == learning["id"] end) do
            new_rule = %{
              "id" => learning["id"],
              "rule" => learning["title"],
              "priority" => learning["priority"],
              "description" => learning["problem"] || learning["pattern"],
              "source" => learning["source"]
            }
            
            updated_bundle = Map.put(bundle, "rules", rules ++ [new_rule])
            
            File.write!(bundle_path, Jason.encode!(updated_bundle, pretty: true))
            Mix.shell().info("  ✅ Updated bundles/#{bundle_file}")
          end
        end
      end
    end)
  end
end
