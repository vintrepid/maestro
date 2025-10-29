defmodule Mix.Tasks.Bundle.Graph do
  @moduledoc """
  Generate a concept graph from a bundle JSON file.
  
  Usage:
    mix bundle.graph sessions
    mix bundle.graph database_work
  """
  
  use Mix.Task
  
  @shortdoc "Generate concept graph from bundle"
  
  def run([bundle_name]) do
    agents_dir = Path.expand("~/dev/agents")
    bundle_path = Path.join([agents_dir, "bundles", "#{bundle_name}.json"])
    
    unless File.exists?(bundle_path) do
      Mix.shell().error("Bundle not found: #{bundle_path}")
      exit({:shutdown, 1})
    end
    
    bundle = bundle_path |> File.read!() |> Jason.decode!()
    
    dot_content = generate_dot(bundle, bundle_name)
    dot_file = "BUNDLE_#{bundle_name}.dot"
    File.write!(dot_file, dot_content)
    
    svg_file = Path.join(["priv", "static", "images", "bundle_#{bundle_name}.svg"])
    File.mkdir_p!(Path.dirname(svg_file))
    
    case System.cmd("dot", ["-Tsvg", dot_file, "-o", svg_file]) do
      {_, 0} ->
        make_svg_responsive(svg_file)
        Mix.shell().info("✨ Generated: #{svg_file}")
        Mix.shell().info("   View: /concepts/bundles/#{bundle_name}")
      {error, _} ->
        Mix.shell().error("Error: #{error}")
    end
  end
  
  def run(_) do
    Mix.shell().error("Usage: mix bundle.graph <bundle_name>")
  end
  
  defp generate_dot(bundle, bundle_name) do
    concepts = Map.get(bundle, "concepts", %{})
    relationships = Map.get(bundle, "relationships", [])
    
    """
    digraph #{bundle_name} {
      rankdir=LR;
      node [shape=box, style=filled, fillcolor=lightblue];
      label="#{bundle["description"]}";
      labelloc=t;
      
      // Concepts
      #{Enum.map_join(concepts, "\n", fn {key, data} ->
        summary = String.slice(data["summary"], 0..40)
        learned_from = data["learned_from"]
        "  #{key} [label=\"#{format_label(key)}\\n#{summary}\\n(#{learned_from})\"];"
      end)}
      
      // Relationships
      #{Enum.map_join(relationships, "\n", fn rel ->
        "  #{rel["from"]} -> #{rel["to"]} [label=\"#{rel["type"]}\"];"
      end)}
      
      // Connect to source files
      #{Enum.map_join(Map.get(bundle, "includes", []), "\n", fn file ->
        id = make_id(file)
        "  #{id} [label=\"📄 #{file}\" fillcolor=lightyellow shape=note];"
      end)}
      
      #{Enum.map_join(concepts, "\n", fn {key, data} ->
        file_id = make_id(data["learned_from"])
        "  #{file_id} -> #{key} [style=dashed label=\"teaches\"];"
      end)}
    }
    """
  end
  
  defp format_label(key) do
    key
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
  
  defp make_id(filename) do
    filename
    |> String.replace(~r/[^a-zA-Z0-9]/, "_")
  end
  
  defp make_svg_responsive(svg_path) do
    content = File.read!(svg_path)
    
    responsive_content = content
    |> String.replace(~r/<\?xml[^>]*\?>/i, "")
    |> String.replace(~r/<!DOCTYPE[^>]*>/i, "")
    |> String.replace(~r/<svg([^>]*) width="[^"]*"/, "<svg\\1")
    |> String.replace(~r/<svg([^>]*) height="[^"]*"/, "<svg\\1")
    |> String.replace("<svg", "<svg style=\"width: 100%; height: auto;\"")
    |> String.trim()
    
    File.write!(svg_path, responsive_content)
  end
end
