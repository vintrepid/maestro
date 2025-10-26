defmodule Maestro.HEExTransformer do
  @moduledoc """
  Transforms HEEx templates using Floki HTML parser while preserving embedded Elixir.
  Uses marker tags that get replaced after Floki serialization.
  """

  def transform_section_cards(heex_string) do
    {:ok, doc} = Floki.parse_fragment(heex_string)
    
    transformed = Floki.traverse_and_update(doc, fn
      {"div", attrs, children} = node ->
        class_attr = Enum.find(attrs, fn {k, _} -> k == "class" end)
        
        case class_attr do
          {"class", class} when is_binary(class) ->
            if String.contains?(class, "card bg-base-100 shadow-xl") do
              extra = String.replace(class, "card bg-base-100 shadow-xl", "") |> String.trim()
              
              inner_content = case children do
                [{"div", body_attrs, body_children} | rest] ->
                  body_class = Enum.find(body_attrs, fn {k, _} -> k == "class" end)
                  case body_class do
                    {"class", "card-body"} -> body_children ++ rest
                    _ -> children
                  end
                _ -> children
              end
              
              # Use marker tag with data attribute for classes
              marker_attrs = if extra != "", do: [{"data-component-class", extra}], else: []
              {"PHOENIX_SECTION_CARD", marker_attrs, inner_content}
            else
              node
            end
          _ -> node
        end
        
      node -> node
    end)
    
    # Let Floki serialize (preserves structure properly)
    html = Floki.raw_html(transformed)
    
    # Replace markers with component syntax, unescaping HTML entities
    html
    |> String.replace(~r/<PHOENIX_SECTION_CARD data-component-class="([^"]+)">/, "<.section_card class=\"\\1\">")
    |> String.replace("<PHOENIX_SECTION_CARD>", "<.section_card>")
    |> String.replace("</PHOENIX_SECTION_CARD>", "</.section_card>")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
  end
  
  def transform_stats_grids(heex_string) do
    {:ok, doc} = Floki.parse_fragment(heex_string)
    
    transformed = Floki.traverse_and_update(doc, fn
      {"div", attrs, children} = node ->
        class_attr = Enum.find(attrs, fn {k, _} -> k == "class" end)
        
        case class_attr do
          {"class", class} when is_binary(class) ->
            if String.contains?(class, "stats stats-vertical lg:stats-horizontal") do
              base_pattern = ~r/stats\s+stats-vertical\s+lg:stats-horizontal\s+shadow\s*/
              extra = String.replace(class, base_pattern, "") |> String.trim()
              
              marker_attrs = if extra != "", do: [{"data-component-class", extra}], else: []
              {"PHOENIX_STATS_GRID", marker_attrs, children}
            else
              node
            end
          _ -> node
        end
        
      node -> node
    end)
    
    html = Floki.raw_html(transformed)
    
    html
    |> String.replace(~r/<PHOENIX_STATS_GRID data-component-class="([^"]+)">/, "<.stats_grid class=\"\\1\">")
    |> String.replace("<PHOENIX_STATS_GRID>", "<.stats_grid>")
    |> String.replace("</PHOENIX_STATS_GRID>", "</.stats_grid>")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
  end
end
