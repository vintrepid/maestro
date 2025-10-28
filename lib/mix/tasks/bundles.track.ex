defmodule Mix.Tasks.Bundles.Track do
  @moduledoc """
  Track token usage and guideline references for bundle optimization.
  
  ## Usage
  
      # Initialize tracking for a session
      mix bundles.track init circle feature/user-profiles bootstrap,ui_work
      
      # Log a guideline reference
      mix bundles.track ref git_feature_branch "Creating feature branch"
      
      # End session and summarize
      mix bundles.track summary
  
  """
  use Mix.Task

  @shortdoc "Track bundle usage for optimization"
  
  @tracker_file "agents/GUIDELINE_USAGE_TRACKER.md"

  def run(["init", project, branch, bundles]) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    bundle_list = String.split(bundles, ",")
    
    entry = """
    
    ## Session: #{project} - #{timestamp}
    
    **Branch:** #{branch}
    **Bundles loaded:** #{Enum.join(bundle_list, ", ")}
    **Start time:** #{timestamp}
    
    ### Guidelines Referenced
    
    ```
    """
    
    File.write!(@tracker_file, File.read!(@tracker_file) <> entry, [:append])
    Mix.shell().info("✓ Session tracking initialized")
  end
  
  def run(["ref", guideline_id, context]) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    
    entry = "#{timestamp} #{guideline_id} - #{context}\n"
    
    File.write!(@tracker_file, entry, [:append])
    Mix.shell().info("✓ Logged: #{guideline_id}")
  end
  
  def run(["summary"]) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    
    entry = """
    ```
    
    **End time:** #{timestamp}
    
    ---
    """
    
    File.write!(@tracker_file, entry, [:append])
    Mix.shell().info("✓ Session summary added")
  end
  
  def run(_) do
    Mix.shell().info("""
    Usage:
      mix bundles.track init <project> <branch> <bundles>
      mix bundles.track ref <guideline_id> <context>
      mix bundles.track summary
    """)
  end
end
