defmodule Mix.Tasks.Startup.Build do
  @moduledoc """
  Builds startup.json with minimal essential content for agent startup.
  
  This should be run at the end of each session to prepare for the next agent.
  
  ## Usage
  
      mix startup.build
  
  Creates startup.json with:
  - Project README content
  - Essential startup docs (not full bootstrap bundle)
  - Current task context
  - Workflow instructions
  - Anti-patterns list
  
  Full bundles (bootstrap, ui, models, etc.) are loaded on-demand, not at startup.
  """
  use Mix.Task

  @shortdoc "Build startup.json with bundled content"
  
  def run(_args) do
    readme_path = "README.md"
    agents_home = Path.join([System.user_home!(), "dev", "agents"])
    bootstrap_docs = Path.join(agents_home, "docs/bootstrap")
    aliases_path = Path.join([System.user_home!(), "dev", "agents", "core", "ALIASES.md"])
    task_path = "current_task.json"
    
    unless File.exists?(readme_path) do
      Mix.raise("README.md not found in project root")
    end
    
    readme_content = File.read!(readme_path)
    
    essential_docs = [
      "GUIDELINES.md",
      "AGENTS_SYMLINK.md",
      "AGENT_OPERATIONS_PATTERNS.md",
      "USER_CONTEXT.md"
    ]
    
    bootstrap_content = %{
      "description" => "Essential startup docs only - load other bundles on-demand",
      "includes" => essential_docs,
      "source_files" => essential_docs
      |> Enum.map(fn file -> 
        path = Path.join(bootstrap_docs, file)
        if File.exists?(path) do
          {file, File.read!(path)}
        else
          Mix.shell().info("Warning: #{file} not found, skipping")
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Map.new()
    }
    
    aliases_content = if File.exists?(aliases_path) do
      File.read!(aliases_path)
    else
      nil
    end
    
    task_content = if File.exists?(task_path) do
      File.read!(task_path) |> Jason.decode!()
    else
      nil
    end
    
    startup = %{
      "session" => "maestro_startup",
      "version" => "2.0.0",
      "description" => "Startup configuration for Maestro AI sessions - all content bundled",
      "generated_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      
      "START_HERE" => %{
        "purpose" => "ONE IN THREE AGENTS GET LOST AT STARTUP. Follow this checklist BEFORE doing anything else.",
        "checklist" => [
          "1. STOP - Don't jump into implementation",
          "2. READ workflow section below (6 steps)",
          "3. RUN: mix bundles.track init maestro <branch> bootstrap",
          "4. CHECK task section for your assignment",
          "5. IF task unclear: Ask user BEFORE starting",
          "6. THEN proceed with workflow step 4+"
        ],
        "common_mistakes" => [
          "Skipping bundles.track init (YOU JUST DID THIS)",
          "Not reading the task section (scroll down to 'task' key)",
          "Jumping straight to browser_eval instead of reading code",
          "Trying to coordinate tasks meant for other agents",
          "Forgetting to log guideline refs with bundles.track ref"
        ],
        "tools_available" => [
          "mix maestro.task.read TASK_ID - Read any task",
          "mix maestro.task.update TASK_ID status VALUE - Update task",
          "mix bundles.track ref GUIDELINE_ID 'what you did' - Log usage",
          "mix bundles.track summary - End session logging",
          "mix startup.build - Regenerate this file (at end)"
        ]
      },
      
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
      
      "task" => if task_content do
        %{
          "content" => task_content,
          "purpose" => "Current ongoing task and context"
        }
      else
        nil
      end,
      
      "workflow" => %{
        "1_start_session" => "Read this file (startup.json) - everything bundled here",
        "2_init_tracking" => "mix bundles.track init maestro <branch> bootstrap",
        "3_check_task" => "Read current_task.json for assigned work",
        "4_load_contextual" => "If task involves another project, read their README. If task type known, load relevant bundle (ui, models, etc). For library patterns, consult USAGE_RULES.md",
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
    
    file_size = byte_size(json)
    Mix.shell().info("✓ Built startup.json with essential content")
    Mix.shell().info("  - Total size: #{file_size} bytes (#{Float.round(file_size/1024, 1)} KB)")
    Mix.shell().info("  - README.md (#{byte_size(readme_content)} bytes)")
    Mix.shell().info("  - Essential docs: #{length(essential_docs)} files")
    if aliases_content do
      Mix.shell().info("  - ALIASES.md (#{byte_size(aliases_content)} bytes)")
    end
    if task_content do
      Mix.shell().info("  - current_task.json (task ##{task_content["task_id"]})")
    end
    Mix.shell().info("\nNext agent can read just startup.json to get started!")
  end
end
