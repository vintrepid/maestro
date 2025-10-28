defmodule Mix.Tasks.Startup.Build do
  @moduledoc """
  Builds startup.json by bundling README.md and bootstrap guidelines.
  
  This should be run at the end of each session to prepare for the next agent.
  
  ## Usage
  
      mix startup.build
  
  Creates startup.json with:
  - Project README content
  - Bootstrap bundle content
  - Workflow instructions
  - Anti-patterns list
  """
  use Mix.Task

  @shortdoc "Build startup.json with bundled content"
  
  def run(_args) do
    readme_path = "README.md"
    bootstrap_path = Path.join([System.user_home!(), "dev", "agents", "bundles", "bootstrap.json"])
    aliases_path = Path.join([System.user_home!(), "dev", "agents", "core", "ALIASES.md"])
    usage_rules_path = "USAGE_RULES.md"
    
    unless File.exists?(readme_path) do
      Mix.raise("README.md not found in project root")
    end
    
    unless File.exists?(bootstrap_path) do
      Mix.raise("Bootstrap bundle not found at #{bootstrap_path}")
    end
    
    readme_content = File.read!(readme_path)
    bootstrap_content = File.read!(bootstrap_path) |> Jason.decode!()
    
    aliases_content = if File.exists?(aliases_path) do
      File.read!(aliases_path)
    else
      nil
    end
    
    usage_rules_content = if File.exists?(usage_rules_path) do
      File.read!(usage_rules_path)
    else
      nil
    end
    
    startup = %{
      "session" => "maestro_startup",
      "version" => "2.0.0",
      "description" => "Startup configuration for Maestro AI sessions - all content bundled",
      "generated_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      
      "readme" => %{
        "content" => readme_content,
        "purpose" => "Know who you are - project identity, purpose, ports"
      },
      
      "bootstrap" => %{
        "content" => bootstrap_content,
        "purpose" => "Minimal core rules - git workflow, verification, tracking"
      },
      
      "aliases" => if aliases_content do
        %{
          "content" => aliases_content,
          "purpose" => "Conversational shortcuts user employs (hi, bye, gpb, learn, wip, ci)"
        }
      else
        nil
      end,
      
      "usage_rules" => if usage_rules_content do
        %{
          "content" => usage_rules_content,
          "purpose" => "Library-specific patterns (Ash, Phoenix, Ecto, LiveView, etc.)"
        }
      else
        nil
      end,
      
      "workflow" => %{
        "1_start_session" => "Read this file (startup.json) - everything bundled here",
        "2_init_tracking" => "mix bundles.track init maestro <branch> bootstrap",
        "3_check_task" => "Read current_task.json for assigned work",
        "4_load_contextual" => "If task involves another project, read their README. If task type known, load relevant bundle",
        "5_work" => "Execute task, logging guideline usage as you go",
        "6_end_session" => "mix bundles.track summary && mix session.capacity <used> 200000 && mix startup.build"
      },
      
      "anti_patterns" => [
        "Trying to read agents/* files (they're symlinked, causes confusion)",
        "Loading all bundles upfront",
        "Reading documentation 'just in case'",
        "Trying to memorize everything before starting",
        "Loading project READMEs you're not working with"
      ],
      
      "philosophy" => "Load less, reference more. Read what you need when you need it. Everything you need to start is in this file."
    }
    
    json = Jason.encode!(startup, pretty: true)
    File.write!("startup.json", json)
    
    Mix.shell().info("✓ Built startup.json with bundled content")
    Mix.shell().info("  - README.md (#{byte_size(readme_content)} bytes)")
    Mix.shell().info("  - Bootstrap bundle (#{map_size(bootstrap_content)} keys)")
    if aliases_content do
      Mix.shell().info("  - ALIASES.md (#{byte_size(aliases_content)} bytes)")
    end
    if usage_rules_content do
      Mix.shell().info("  - USAGE_RULES.md (#{byte_size(usage_rules_content)} bytes)")
    end
    Mix.shell().info("\nNext agent can read just startup.json to get started!")
  end
end
