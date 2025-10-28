defmodule Mix.Tasks.Bundles.Analyze do
  @moduledoc """
  Analyze bundle usage patterns and suggest improvements.
  
  ## Usage
  
      # Analyze overall usage
      mix bundles.analyze
      
      # Analyze specific bundle
      mix bundles.analyze bootstrap
      
      # Compare bundles
      mix bundles.analyze --compare bootstrap ui_work
  
  """
  use Mix.Task

  @shortdoc "Analyze bundle usage and effectiveness"
  
  @tracker_file "agents/GUIDELINE_USAGE_TRACKER.md"

  def run([]) do
    unless File.exists?(@tracker_file) do
      Mix.shell().error("No tracking data found. Use `mix bundles.track` to start tracking.")
      
    end
    
    content = File.read!(@tracker_file)
    sessions = parse_sessions(content)
    
    Mix.shell().info("Bundle Usage Analysis")
    Mix.shell().info("=" |> String.duplicate(50))
    Mix.shell().info("")
    Mix.shell().info("Total sessions tracked: #{length(sessions)}")
    Mix.shell().info("")
    
    # Analyze by bundle
    bundle_stats = analyze_by_bundle(sessions)
    
    Mix.shell().info("Usage by Bundle:")
    Enum.each(bundle_stats, fn {bundle, stats} ->
      Mix.shell().info("  #{bundle}:")
      Mix.shell().info("    Sessions: #{stats.session_count}")
      Mix.shell().info("    Avg references: #{Float.round(stats.avg_refs, 1)}")
      Mix.shell().info("    Most used: #{Enum.take(stats.top_guidelines, 3) |> Enum.join(", ")}")
    end)
    
    Mix.shell().info("")
    
    # Find missing guidelines (referenced but not in bundle)
    missing = find_missing_guidelines(sessions)
    if missing != [] do
      Mix.shell().info("⚠️  Guidelines referenced but not in bundles:")
      Enum.each(missing, fn {guideline, count} ->
        Mix.shell().info("    #{guideline} (#{count}x)")
      end)
    end
    
    Mix.shell().info("")
    
    # Find unused guidelines (in bundle but never referenced)
    unused = find_unused_guidelines(sessions)
    if unused != [] do
      Mix.shell().info("📦 Guidelines in bundles but never used:")
      Enum.each(unused, fn guideline ->
        Mix.shell().info("    #{guideline}")
      end)
    end
  end
  
  def run([bundle_name]) do
    content = File.read!(@tracker_file)
    sessions = parse_sessions(content)
    
    bundle_sessions = Enum.filter(sessions, fn session ->
      bundle_name in session.bundles
    end)
    
    if bundle_sessions == [] do
      Mix.shell().error("No sessions found using #{bundle_name} bundle")
      
    end
    
    Mix.shell().info("Analysis for #{bundle_name} bundle")
    Mix.shell().info("=" |> String.duplicate(50))
    Mix.shell().info("Sessions: #{length(bundle_sessions)}")
    
    all_refs = Enum.flat_map(bundle_sessions, & &1.references)
    ref_counts = Enum.frequencies(all_refs)
    
    Mix.shell().info("\nMost referenced guidelines:")
    ref_counts
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(10)
    |> Enum.each(fn {guideline, count} ->
      Mix.shell().info("  #{guideline}: #{count}x")
    end)
  end
  
  defp parse_sessions(content) do
    content
    |> String.split("## Session:")
    |> Enum.drop(1)
    |> Enum.map(&parse_session/1)
  end
  
  defp parse_session(text) do
    [header | rest] = String.split(text, "\n", parts: 2)
    
    bundles = Regex.run(~r/Bundles loaded:\*\* (.+)/, text)
    bundles = if bundles, do: String.split(Enum.at(bundles, 1), ", "), else: []
    
    references = 
      rest
      |> List.first()
      |> String.split("\n")
      |> Enum.filter(&String.contains?(&1, " - "))
      |> Enum.map(fn line ->
        line
        |> String.split(" ")
        |> Enum.at(1)
      end)
      |> Enum.filter(& &1)
    
    %{
      project: String.trim(header),
      bundles: bundles,
      references: references
    }
  end
  
  defp analyze_by_bundle(sessions) do
    sessions
    |> Enum.flat_map(fn session ->
      Enum.map(session.bundles, fn bundle ->
        {bundle, session.references}
      end)
    end)
    |> Enum.group_by(fn {bundle, _} -> bundle end, fn {_, refs} -> refs end)
    |> Enum.map(fn {bundle, ref_lists} ->
      all_refs = List.flatten(ref_lists)
      {bundle, %{
        session_count: length(ref_lists),
        avg_refs: length(all_refs) / length(ref_lists),
        top_guidelines: all_refs |> Enum.frequencies() |> Enum.sort_by(fn {_, c} -> c end, :desc) |> Enum.take(5) |> Enum.map(fn {g, _} -> g end)
      }}
    end)
    |> Map.new()
  end
  
  defp find_missing_guidelines(_sessions) do
    # TODO: Compare referenced guidelines vs bundle contents
    []
  end
  
  defp find_unused_guidelines(_sessions) do
    # TODO: Compare bundle contents vs referenced guidelines
    []
  end
end
