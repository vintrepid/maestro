defmodule MaestroWeb.BookmarkImportLive do
  use MaestroWeb, :live_view
  alias Maestro.Resources.BookmarkImporter

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Import Bookmarks")
     |> assign(:uploaded_files, [])
     |> assign(:importing, false)
     |> allow_upload(:bookmarks, accept: [".html", ".htm"], max_entries: 1)}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :bookmarks, ref)}
  end

  def handle_event("import", _params, socket) do
    socket = assign(socket, :importing, true)
    
    uploaded_files =
      consume_uploaded_entries(socket, :bookmarks, fn %{path: path}, _entry ->
        html_content = File.read!(path)
        
        case BookmarkImporter.import_from_html(html_content, "User", "1") do
          {:ok, results} ->
            success_count = Enum.count(results, fn
              {:ok, _} -> true
              _ -> false
            end)
            {:ok, %{success_count: success_count, total: length(results)}}
          
          {:error, reason} ->
            {:postpone, reason}
        end
      end)

    case uploaded_files do
      [%{success_count: success, total: total}] ->
        {:noreply,
         socket
         |> assign(:importing, false)
         |> put_flash(:info, "Imported #{success} of #{total} bookmarks successfully")
         |> push_navigate(to: ~p"/resources")}
      
      [] ->
        {:noreply,
         socket
         |> assign(:importing, false)
         |> put_flash(:error, "Please select a file to import")}
      
      _ ->
        {:noreply,
         socket
         |> assign(:importing, false)
         |> put_flash(:error, "Import failed")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="max-w-2xl mx-auto px-8 py-12">
        <div class="mb-8">
          <h2 class="text-2xl font-semibold">Import Bookmarks</h2>
          <p class="text-base-content/60 mt-2">
            Upload an HTML bookmarks file exported from your browser. 
            Folders will be converted to tags with hierarchical relationships.
          </p>
        </div>

        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <form phx-submit="import" phx-change="validate">
              <div class="form-control">
                <label class="label">
                  <span class="label-text">Bookmark File</span>
                </label>
                
                <div class="border-2 border-dashed border-base-300 rounded-lg p-8 text-center">
                  <.live_file_input upload={@uploads.bookmarks} class="hidden" id="bookmark-upload" />
                  
                  <label for="bookmark-upload" class="cursor-pointer">
                    <.icon name="hero-arrow-up-tray" class="w-12 h-12 mx-auto text-base-content/40" />
                    <p class="mt-2 text-sm text-base-content/60">
                      Click to upload or drag and drop
                    </p>
                    <p class="text-xs text-base-content/40 mt-1">
                      HTML files only
                    </p>
                  </label>
                </div>

                <%= for entry <- @uploads.bookmarks.entries do %>
                  <div class="mt-4 p-4 bg-base-200 rounded-lg flex items-center justify-between">
                    <div class="flex items-center gap-3">
                      <.icon name="hero-document" class="w-5 h-5" />
                      <div>
                        <p class="font-medium">{entry.client_name}</p>
                        <p class="text-sm text-base-content/60">
                          {format_bytes(entry.client_size)}
                        </p>
                      </div>
                    </div>
                    
                    <button
                      type="button"
                      phx-click="cancel-upload"
                      phx-value-ref={entry.ref}
                      class="btn btn-ghost btn-sm btn-circle"
                    >
                      <.icon name="hero-x-mark" class="w-4 h-4" />
                    </button>
                  </div>

                  <%= for err <- upload_errors(@uploads.bookmarks, entry) do %>
                    <div class="alert alert-error mt-2">
                      <span>{error_to_string(err)}</span>
                    </div>
                  <% end %>
                <% end %>

                <%= for err <- upload_errors(@uploads.bookmarks) do %>
                  <div class="alert alert-error mt-2">
                    <span>{error_to_string(err)}</span>
                  </div>
                <% end %>
              </div>

              <div class="card-actions justify-end mt-6">
                <.link navigate={~p"/resources"} class="btn btn-ghost">
                  Cancel
                </.link>
                <button 
                  type="submit" 
                  class="btn btn-primary"
                  disabled={@importing || @uploads.bookmarks.entries == []}
                >
                  <%= if @importing do %>
                    <span class="loading loading-spinner loading-sm"></span>
                    Importing...
                  <% else %>
                    <.icon name="hero-arrow-down-tray" class="w-5 h-5" />
                    Import Bookmarks
                  <% end %>
                </button>
              </div>
            </form>
          </div>
        </div>

        <div class="mt-8 card bg-base-200">
          <div class="card-body">
            <h3 class="font-semibold">How to export bookmarks</h3>
            
            <div class="mt-4 space-y-4">
              <div>
                <h4 class="font-medium">Chrome / Edge</h4>
                <ol class="list-decimal list-inside text-sm text-base-content/80 mt-1 space-y-1">
                  <li>Click the three dots menu → Bookmarks → Bookmark manager</li>
                  <li>Click the three dots in the bookmark manager → Export bookmarks</li>
                </ol>
              </div>
              
              <div>
                <h4 class="font-medium">Firefox</h4>
                <ol class="list-decimal list-inside text-sm text-base-content/80 mt-1 space-y-1">
                  <li>Click the three bars menu → Bookmarks → Manage bookmarks</li>
                  <li>Import and Backup → Export Bookmarks to HTML...</li>
                </ol>
              </div>
              
              <div>
                <h4 class="font-medium">Safari</h4>
                <ol class="list-decimal list-inside text-sm text-base-content/80 mt-1 space-y-1">
                  <li>File → Export → Bookmarks...</li>
                </ol>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp format_bytes(bytes) do
    cond do
      bytes >= 1_000_000 -> "#{Float.round(bytes / 1_000_000, 1)} MB"
      bytes >= 1_000 -> "#{Float.round(bytes / 1_000, 1)} KB"
      true -> "#{bytes} bytes"
    end
  end

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:not_accepted), do: "Invalid file type. Please upload an HTML file."
  defp error_to_string(:too_many_files), do: "Only one file allowed"
  defp error_to_string(err), do: "Upload error: #{inspect(err)}"
end
