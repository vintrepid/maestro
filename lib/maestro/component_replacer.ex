defmodule Maestro.ComponentReplacer do
  @moduledoc """
  Applies component transformations to LiveView files using Floki HTML parser.
  """

  def apply_to_file(file_path, component_name) do
    content = File.read!(file_path)
    
    case apply_transformation(content, component_name) do
      {:ok, new_content} ->
        File.write!(file_path, new_content)
        {:ok, "Transformed #{file_path}"}
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  def apply_transformation(content, "section_card") do
    transform_in_heex(content, &transform_section_card/1)
  end

  def apply_transformation(content, "stats_grid") do
    transform_in_heex(content, &transform_stats_grid/1)
  end

  def apply_transformation(_content, component) do
    {:error, "Unknown component: #{component}"}
  end

  # Find HEEx templates in the file and transform HTML within them
  defp transform_in_heex(content, transform_fn) do
    # Match ~H""" ... """ blocks
    pattern = ~r/~H"""\n(.*?)\n\s*"""/s
    
    new_content = Regex.replace(pattern, content, fn full_match, heex_content ->
      case Floki.parse_fragment(heex_content) do
        {:ok, doc} ->
          transformed = transform_fn.(doc)
          rendered = render_component_html(transformed)
          String.replace(full_match, heex_content, rendered)
          
        _error ->
          full_match
      end
    end)
    
    {:ok, new_content}
  end

  # Transform card divs to section_card component
  defp transform_section_card(doc) do
    Floki.traverse_and_update(doc, fn
      {"div", attrs, children} = node ->
        class = Floki.attribute([node], "class") |> List.first()
        
        if class && String.contains?(class, "card bg-base-100 shadow-xl") do
          # Extract extra classes
          extra_classes = class
            |> String.replace("card bg-base-100 shadow-xl", "")
            |> String.trim()
          
          # Find and unwrap card-body
          inner_content = case children do
            [{"div", inner_attrs, inner_children}] ->
              inner_class = Floki.attribute([{"div", inner_attrs, inner_children}], "class") |> List.first()
              if inner_class == "card-body" do
                inner_children
              else
                children
              end
            _ -> children
          end
          
          # Build component
          component_attrs = if extra_classes != "", do: [{"class", extra_classes}], else: []
          {:component, "section_card", component_attrs, inner_content}
        else
          node
        end
        
      node -> node
    end)
  end

  # Transform stats divs to stats_grid component  
  defp transform_stats_grid(doc) do
    Floki.traverse_and_update(doc, fn
      {"div", attrs, children} = node ->
        class = Floki.attribute([node], "class") |> List.first()
        
        if class && String.contains?(class, "stats stats-vertical lg:stats-horizontal") do
          # Extract extra classes
          base_pattern = ~r/stats\s+stats-vertical\s+lg:stats-horizontal\s+shadow\s*/
          extra_classes = String.replace(class, base_pattern, "") |> String.trim()
          
          # Build component
          component_attrs = if extra_classes != "", do: [{"class", extra_classes}], else: []
          {:component, "stats_grid", component_attrs, children}
        else
          node
        end
        
      node -> node
    end)
  end

  # Custom renderer for Phoenix components
  defp render_component_html(doc) do
    doc
    |> Enum.map(&render_node(&1, 0))
    |> Enum.join("")
  end
  
  defp render_node({:component, name, attrs, children}, indent) do
    attrs_str = case attrs do
      [] -> ""
      attrs -> " " <> Enum.map_join(attrs, " ", fn {k, v} -> ~s(#{k}="#{v}") end)
    end
    
    indent_str = String.duplicate("  ", indent)
    children_html = Enum.map_join(children, "", &render_node(&1, indent + 1))
    
    "<.#{name}#{attrs_str}>\\n#{children_html}#{indent_str}</.#{name}>"
  end
  
  defp render_node({tag, attrs, children}, indent) when is_binary(tag) do
    attrs_str = case attrs do
      [] -> ""
      attrs -> " " <> Enum.map_join(attrs, " ", fn {k, v} -> ~s(#{k}="#{v}") end)
    end
    
    indent_str = String.duplicate("  ", indent)
    children_html = Enum.map_join(children, "", &render_node(&1, indent + 1))
    
    if children_html == "" do
      "#{indent_str}<#{tag}#{attrs_str} />\\n"
    else
      "#{indent_str}<#{tag}#{attrs_str}>#{children_html}#{indent_str}</#{tag}>\\n"
    end
  end
  
  defp render_node(text, _indent) when is_binary(text), do: text
  defp render_node({:comment, comment}, indent) do
    indent_str = String.duplicate("  ", indent)
    "#{indent_str}<!--#{comment}-->\\n"
  end
end
