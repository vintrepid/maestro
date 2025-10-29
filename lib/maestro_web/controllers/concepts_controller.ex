defmodule MaestroWeb.ConceptsController do
  use MaestroWeb, :controller

  def index(conn, _params) do
    svg_path = Path.join([Application.app_dir(:maestro), "priv", "static", "images", "concept_dag.svg"])
    svg_exists = File.exists?(svg_path)
    svg_content = if svg_exists, do: File.read!(svg_path), else: nil
    
    render(conn, :index, svg_exists: svg_exists, svg_content: svg_content)
  end

  def directory(conn, %{"dir" => dir}) do
    agents_dir = Path.expand("~/dev/agents")
    dir_path = Path.join(agents_dir, dir)
    
    if File.dir?(dir_path) do
      svg_path = Path.join([Application.app_dir(:maestro), "priv", "static", "images", "concept_dag_#{dir}.svg"])
      
      unless File.exists?(svg_path) do
        generate_directory_dag(dir, dir_path)
      end
      
      svg_content = load_directory_svg(dir)
      render(conn, :directory, dir: dir, svg_content: svg_content)
    else
      conn
      |> put_flash(:error, "Directory not found: #{dir}")
      |> redirect(to: ~p"/concepts")
    end
  end

  def file(conn, %{"dir" => dir, "file" => file}) do
    agents_dir = Path.expand("~/dev/agents")
    file_path = Path.join([agents_dir, dir, URI.decode(file)])
    
    if File.exists?(file_path) do
      content = File.read!(file_path)
      render(conn, :file, dir: dir, file: URI.decode(file), content: content)
    else
      conn
      |> put_flash(:error, "File not found")
      |> redirect(to: ~p"/concepts/#{dir}")
    end
  end

  def bundle_graph(conn, %{"bundle" => bundle}) do
    svg_path = Path.join([Application.app_dir(:maestro), "priv", "static", "images", "bundle_#{bundle}.svg"])
    
    if File.exists?(svg_path) do
      svg_content = File.read!(svg_path)
      render(conn, :bundle_graph, bundle: bundle, svg_content: svg_content)
    else
      conn
      |> put_flash(:error, "Bundle graph not found. Run: mix bundle.graph #{bundle}")
      |> redirect(to: ~p"/concepts")
    end
  end

  defp generate_directory_dag(dir_name, dir_path) do
    files = File.ls!(dir_path)
    |> Enum.filter(&(!String.starts_with?(&1, ".")))
    |> Enum.sort()
    
    dot_content = """
    digraph #{String.replace(dir_name, "-", "_")}Directory {
      rankdir=LR;
      node [shape=box, style=filled, fillcolor=lightblue];
      
      #{Enum.map_join(files, "\n", fn file ->
        id = String.replace(file, ~r/[^a-zA-Z0-9]/, "_")
        label = String.replace(file, "_", " ")
        url = "/concepts/#{dir_name}/#{URI.encode(file)}"
        "  #{id} [label=\"#{label}\" URL=\"#{url}\"];"
      end)}
      
      #{generate_session_relationships(files)}
    }
    """
    
    dot_path = "CONCEPT_DAG_#{dir_name}.dot"
    File.write!(dot_path, dot_content)
    
    svg_path = Path.join(["priv", "static", "images", "concept_dag_#{dir_name}.svg"])
    File.mkdir_p!(Path.dirname(svg_path))
    
    case System.cmd("dot", ["-Tsvg", dot_path, "-o", svg_path]) do
      {_, 0} -> 
        make_svg_responsive(svg_path)
        :ok
      {error, _} -> 
        IO.puts("SVG generation error: #{error}")
    end
  end

  defp generate_session_relationships(files) do
    session_learnings = Enum.filter(files, &String.contains?(&1, "SESSION_LEARNINGS"))
    
    relationships = session_learnings
    |> Enum.sort()
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [file1, file2] ->
      id1 = String.replace(file1, ~r/[^a-zA-Z0-9]/, "_")
      id2 = String.replace(file2, ~r/[^a-zA-Z0-9]/, "_")
      "  #{id1} -> #{id2} [label=\"followed by\"];"
    end)
    
    Enum.join(relationships, "\n")
  end

  defp load_directory_svg(dir_name) do
    svg_path = Path.join([Application.app_dir(:maestro), "priv", "static", "images", "concept_dag_#{dir_name}.svg"])
    if File.exists?(svg_path), do: File.read!(svg_path), else: nil
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
