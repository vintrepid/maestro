defmodule Maestro.Resources.WebScraper do
  alias Maestro.Resources.Resource

  def scrape_and_create(url, owner_type, owner_id, opts \\ []) do
    with {:ok, response} <- fetch_page(url),
         {:ok, content} <- extract_content(response),
         {:ok, thumbnail} <- generate_thumbnail(url, opts) do
      
      Resource.create(%{
        title: content.title || url,
        description: content.description,
        url: url,
        content: content.body,
        thumbnail_url: thumbnail,
        resource_type: :website,
        metadata: content.metadata,
        owner_type: owner_type,
        owner_id: owner_id
      })
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_page(url) do
    case Req.get(url, follow_redirects: true, max_redirects: 3) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}
      
      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}
      
      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  defp extract_content(html) do
    case Floki.parse_document(html) do
      {:ok, document} ->
        title = extract_title(document)
        description = extract_meta_description(document)
        body = extract_main_content(document)
        metadata = extract_metadata(document)
        
        {:ok, %{
          title: title,
          description: description,
          body: body,
          metadata: metadata
        }}
      
      {:error, reason} ->
        {:error, "Failed to parse HTML: #{inspect(reason)}"}
    end
  end

  defp extract_title(document) do
    case Floki.find(document, "title") do
      [title | _] -> Floki.text(title) |> String.trim()
      [] -> nil
    end
  end

  defp extract_meta_description(document) do
    case Floki.find(document, "meta[name='description']") do
      [meta | _] -> 
        Floki.attribute(meta, "content") |> List.first()
      [] ->
        case Floki.find(document, "meta[property='og:description']") do
          [meta | _] -> Floki.attribute(meta, "content") |> List.first()
          [] -> nil
        end
    end
  end

  defp extract_main_content(document) do
    main_content = 
      Floki.find(document, "main") ++
      Floki.find(document, "article") ++
      Floki.find(document, "[role='main']")
    
    case main_content do
      [content | _] -> 
        Floki.text(content) 
        |> String.trim() 
        |> String.slice(0, 5000)
      [] ->
        Floki.find(document, "body")
        |> Floki.text()
        |> String.trim()
        |> String.slice(0, 5000)
    end
  end

  defp extract_metadata(document) do
    %{
      og_image: extract_og_image(document),
      og_url: extract_og_url(document),
      canonical: extract_canonical(document),
      author: extract_author(document),
      published_time: extract_published_time(document)
    }
  end

  defp extract_og_image(document) do
    case Floki.find(document, "meta[property='og:image']") do
      [meta | _] -> Floki.attribute(meta, "content") |> List.first()
      [] -> nil
    end
  end

  defp extract_og_url(document) do
    case Floki.find(document, "meta[property='og:url']") do
      [meta | _] -> Floki.attribute(meta, "content") |> List.first()
      [] -> nil
    end
  end

  defp extract_canonical(document) do
    case Floki.find(document, "link[rel='canonical']") do
      [link | _] -> Floki.attribute(link, "href") |> List.first()
      [] -> nil
    end
  end

  defp extract_author(document) do
    case Floki.find(document, "meta[name='author']") do
      [meta | _] -> Floki.attribute(meta, "content") |> List.first()
      [] -> nil
    end
  end

  defp extract_published_time(document) do
    case Floki.find(document, "meta[property='article:published_time']") do
      [meta | _] -> Floki.attribute(meta, "content") |> List.first()
      [] -> nil
    end
  end

  defp generate_thumbnail(url, opts) do
    if Keyword.get(opts, :skip_thumbnail, false) do
      {:ok, nil}
    else
      case capture_screenshot(url) do
        {:ok, thumbnail_path} -> {:ok, thumbnail_path}
        {:error, _} -> {:ok, nil}
      end
    end
  end

  defp capture_screenshot(_url) do
    {:ok, nil}
  end
end
