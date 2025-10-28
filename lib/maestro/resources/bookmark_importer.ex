defmodule Maestro.Resources.BookmarkImporter do
  alias Maestro.Resources.{Resource, Tag, ResourceTag}
  alias Maestro.Repo

  def import_from_html(html_content, owner_type, owner_id) do
    case parse_bookmarks(html_content) do
      {:ok, bookmarks} ->
        results = 
          bookmarks
          |> Enum.map(fn bookmark -> 
            create_resource_with_tags(bookmark, owner_type, owner_id)
          end)
        
        {:ok, results}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_bookmarks(html_content) do
    case Floki.parse_document(html_content) do
      {:ok, document} ->
        bookmarks = extract_bookmarks(document, [])
        {:ok, bookmarks}
      
      {:error, reason} ->
        {:error, "Failed to parse HTML: #{inspect(reason)}"}
    end
  end

  defp extract_bookmarks(html_tree, path \\ []) do
    Floki.find(html_tree, "dt")
    |> Enum.flat_map(fn dt ->
      case extract_bookmark_or_folder(dt, path) do
        {:bookmark, bookmark} -> [bookmark]
        {:folder, folder_name, children} ->
          extract_bookmarks(children, path ++ [folder_name])
        :skip -> []
      end
    end)
  end

  defp extract_bookmark_or_folder(dt, path) do
    case Floki.find(dt, "a") do
      [link | _] ->
        title = Floki.text(link)
        url = Floki.attribute(link, "href") |> List.first()
        
        {:bookmark, %{
          title: title,
          url: url,
          tags: path,
          resource_type: :website
        }}
      
      [] ->
        case Floki.find(dt, "h3") do
          [h3 | _] ->
            folder_name = Floki.text(h3)
            dl = Floki.find(dt, "dl") |> List.first()
            {:folder, folder_name, dl || []}
          
          [] -> :skip
        end
    end
  end

  defp create_resource_with_tags(bookmark, owner_type, owner_id) do
    Repo.transaction(fn ->
      case Resource.create(%{
        title: bookmark.title,
        url: bookmark.url,
        resource_type: bookmark.resource_type,
        owner_type: owner_type,
        owner_id: owner_id
      }) do
        {:ok, resource} ->
          tag_ids = ensure_tags_exist(bookmark.tags, owner_type, owner_id)
          
          Enum.each(tag_ids, fn tag_id ->
            ResourceTag.create(%{resource_id: resource.id, tag_id: tag_id})
          end)
          
          create_tag_hierarchy(tag_ids)
          
          {:ok, resource}
        
        {:error, reason} ->
          Repo.rollback(reason)
      end
    end)
  end

  defp ensure_tags_exist(tag_names, owner_type, owner_id) do
    Enum.map(tag_names, fn name ->
      slug = Slug.slugify(name)
      
      case Tag.by_slug(%{slug: slug}) do
        {:ok, tag} ->
          tag.id
        
        {:error, _} ->
          case Tag.create(%{
            name: name,
            slug: slug,
            owner_type: owner_type,
            owner_id: owner_id
          }) do
            {:ok, tag} -> tag.id
            {:error, _} -> nil
          end
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp create_tag_hierarchy([]), do: :ok
  defp create_tag_hierarchy([_single]), do: :ok
  defp create_tag_hierarchy(tag_ids) do
    tag_ids
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.each(fn [parent_id, child_id] ->
      Maestro.Resources.TagHierarchy.create(%{
        parent_tag_id: parent_id,
        child_tag_id: child_id
      })
    end)
  end
end
