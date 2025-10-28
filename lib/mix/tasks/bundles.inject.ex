defmodule Mix.Tasks.Bundles.Inject do
  @moduledoc """
  Injects a bundle's content into a project's AGENTS.md file.
  
  ## Usage
  
      mix bundles.inject bootstrap ~/dev/circle/AGENTS.md
      mix bundles.inject ui_work ~/dev/circle/AGENTS.md --append
  
  ## Options
  
    * `--append` - Append to existing AGENTS.md instead of replacing
    * `--dry-run` - Show what would be written without writing
  
  """
  use Mix.Task

  @shortdoc "Inject bundle content into project AGENTS.md"

  def run(args) do
    {opts, [bundle_name, target_file], _} = 
      OptionParser.parse(args, 
        strict: [append: :boolean, dry_run: :boolean],
        aliases: [a: :append, d: :dry_run]
      )
    
    bundle_path = Path.join(["agents", "bundles", "#{bundle_name}.json"])
    
    unless File.exists?(bundle_path) do
      Mix.raise("Bundle not found: #{bundle_path}")
    end
    
    unless File.exists?(target_file) or not opts[:dry_run] do
      Mix.raise("Target file not found: #{target_file}")
    end
    
    # Read and parse bundle
    bundle = File.read!(bundle_path) |> Jason.decode!()
    
    # Convert to prose
    prose = bundle_to_prose(bundle)
    
    # Write or append
    content = if Keyword.get(opts, :append, false) and File.exists?(target_file) do
      existing = File.read!(target_file)
      existing <> "\n\n" <> prose
    else
      prose
    end
    
    if opts[:dry_run] do
      Mix.shell().info("Would write to #{target_file}:")
      Mix.shell().info(String.slice(content, 0, 500) <> "...")
    else
      File.write!(target_file, content)
      Mix.shell().info("✓ Injected #{bundle_name} bundle into #{target_file}")
    end
  end
  
  defp bundle_to_prose(bundle) do
    """
    # #{bundle["bundle"] |> String.capitalize()} - Agent Guidelines
    
    #{bundle["description"]}
    
    **Version:** #{bundle["version"]}
    **Source bundles:** #{Enum.join(bundle["includes"] || [], ", ")}
    
    ## Session Initialization
    
    **When starting a new session, read:**
    1. This AGENTS.md file (you're reading it now)
    2. Project README.md for project-specific context
    
    Then acknowledge: "Ready! Read #{bundle["bundle"]} guidelines. Current branch: [X]. What should I work on?"
    
    ## Core Guidelines
    
    #{format_rules(bundle["rules"])}
    
    #{if bundle["patterns"], do: format_patterns(bundle["patterns"]), else: ""}
    
    #{if bundle["decision_trees"], do: format_decision_trees(bundle["decision_trees"]), else: ""}
    
    #{if bundle["quick_reference"], do: format_quick_reference(bundle["quick_reference"]), else: ""}
    
    #{if bundle["anti_patterns"], do: format_anti_patterns(bundle["anti_patterns"]), else: ""}
    """
  end
  
  defp format_rules(rules) do
    rules
    |> Enum.group_by(& &1["category"])
    |> Enum.map(fn {category, category_rules} ->
      """
      ### #{String.capitalize(category)} #{priority_emoji(category_rules)}
      
      #{Enum.map_join(category_rules, "\n", &format_rule/1)}
      """
    end)
    |> Enum.join("\n")
  end
  
  defp priority_emoji(rules) do
    if Enum.any?(rules, & &1["priority"] == "critical"), do: "⚠️", else: ""
  end
  
  defp format_rule(rule) do
    examples = if rule["examples"] do
      good = rule["examples"]["good"]
      bad = rule["examples"]["bad"]
      
      """
      
      **Examples:**
      #{if good, do: "✅ Good: `#{format_example(good)}`", else: ""}
      #{if bad, do: "❌ Bad: `#{format_example(bad)}`", else: ""}
      """
    else
      ""
    end
    
    """
    - **#{rule["rule"]}** #{if rule["priority"] == "critical", do: "🔴", else: ""}
      #{if rule["context"], do: "_#{rule["context"]}_", else: ""}
      #{if rule["rationale"], do: "Why: #{rule["rationale"]}", else: ""}#{examples}
    """
  end
  
  defp format_example(example) when is_list(example), do: Enum.join(example, "`, `")
  defp format_example(example), do: example
  
  defp format_patterns(patterns) do
    """
    ## Common Patterns
    
    #{Enum.map_join(patterns, "\n", fn {key, value} ->
      "### #{key}\n```\n#{inspect(value, pretty: true)}\n```"
    end)}
    """
  end
  
  defp format_decision_trees(trees) do
    """
    ## Decision Trees
    
    #{Enum.map_join(trees, "\n", fn {key, tree} ->
      "### #{key}\n#{format_tree(tree)}"
    end)}
    """
  end
  
  defp format_tree(tree) when is_list(tree) do
    Enum.map_join(tree, "\n", fn step ->
      "- #{step["question"]}\n  - Yes → #{step["yes"]}\n  - No → #{step["no"]}"
    end)
  end
  
  defp format_quick_reference(ref) do
    """
    ## Quick Reference
    
    #{Enum.map_join(ref, "\n", fn {key, value} ->
      "**#{key}:** #{format_ref_value(value)}"
    end)}
    """
  end
  
  defp format_ref_value(value) when is_list(value), do: Enum.join(value, ", ")
  defp format_ref_value(value) when is_map(value), do: inspect(value, pretty: true)
  defp format_ref_value(value), do: to_string(value)
  
  defp format_anti_patterns(patterns) do
    """
    ## Anti-Patterns to Avoid
    
    #{Enum.map_join(patterns, "\n", fn pattern ->
      """
      ❌ **#{pattern["pattern"]}**
      - Why: #{pattern["why"]}
      - Instead: #{pattern["instead"]}
      """
    end)}
    """
  end
end
