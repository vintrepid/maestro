defmodule MaestroWeb.ResourceFormLive do
  use MaestroWeb, :live_view
  alias Maestro.Resources.Resource

  @impl true
  def mount(params, _session, socket) do
    resource = if params["id"] do
      case Resource.by_id(params["id"]) do
        {:ok, res} -> res
        _ -> nil
      end
    else
      nil
    end

    form = if resource do
      AshPhoenix.Form.for_update(resource, :update)
    else
      initial_params = %{owner_type: "User", owner_id: "1"}
      initial_params = if params["owner_type"], do: Map.put(initial_params, :owner_type, params["owner_type"]), else: initial_params
      initial_params = if params["owner_id"], do: Map.put(initial_params, :owner_id, params["owner_id"]), else: initial_params
      
      AshPhoenix.Form.for_create(Resource, :create, params: initial_params)
    end

    {:ok,
     socket
     |> assign(:page_title, if(resource, do: "Edit Resource", else: "New Resource"))
     |> assign(:resource, resource)
     |> assign(:form, to_form(form))}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form = socket.assigns.form.source
    |> AshPhoenix.Form.validate(params)
    
    {:noreply, assign(socket, :form, to_form(form))}
  end

  def handle_event("save", %{"form" => params}, socket) do
    form = socket.assigns.form.source
    
    case AshPhoenix.Form.submit(form, params: params) do
      {:ok, resource} ->
        {:noreply,
         socket
         |> put_flash(:info, "Resource saved successfully")
         |> push_navigate(to: ~p"/resources")}
      
      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  def handle_event("scrape_url", %{"url" => url}, socket) do
    case Maestro.Resources.WebScraper.scrape_and_create(
      url,
      socket.assigns.form.source.params["owner_type"] || "User",
      socket.assigns.form.source.params["owner_id"] || "1",
      skip_thumbnail: true
    ) do
      {:ok, resource} ->
        {:noreply,
         socket
         |> put_flash(:info, "Resource scraped and created successfully")
         |> push_navigate(to: ~p"/resources/#{resource.id}/edit")}
      
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to scrape: #{reason}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="max-w-4xl mx-auto px-8 py-12">
        <div class="mb-8">
          <h2 class="text-2xl font-semibold">{@page_title}</h2>
        </div>

        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <.form for={@form} phx-change="validate" phx-submit="save">
              <input type="hidden" name="form[owner_type]" value={@form.source.params["owner_type"] || "User"} />
              <input type="hidden" name="form[owner_id]" value={@form.source.params["owner_id"] || "1"} />
              
              <div class="form-control">
                <label class="label">
                  <span class="label-text">Title</span>
                </label>
                <.input field={@form[:title]} type="text" class="input input-bordered" required />
              </div>

              <div class="grid grid-cols-2 gap-4 mt-4">
                <div class="form-control">
                  <label class="label">
                    <span class="label-text">Type</span>
                  </label>
                  <.input 
                    field={@form[:resource_type]} 
                    type="select" 
                    options={resource_type_options()}
                    class="select select-bordered"
                  />
                </div>

                <div class="form-control">
                  <label class="label">
                    <span class="label-text">Platform</span>
                  </label>
                  <.input field={@form[:platform]} type="text" class="input input-bordered" />
                </div>
              </div>

              <div class="form-control mt-4">
                <label class="label">
                  <span class="label-text">URL</span>
                </label>
                <.input field={@form[:url]} type="url" class="input input-bordered" />
              </div>

              <div class="form-control mt-4">
                <label class="label">
                  <span class="label-text">File Path</span>
                </label>
                <.input field={@form[:file_path]} type="text" class="input input-bordered" />
              </div>

              <div class="form-control mt-4">
                <label class="label">
                  <span class="label-text">Description</span>
                </label>
                <.input field={@form[:description]} type="textarea" class="textarea textarea-bordered h-24" />
              </div>

              <div class="form-control mt-4">
                <label class="label">
                  <span class="label-text">Content</span>
                </label>
                <.input field={@form[:content]} type="textarea" class="textarea textarea-bordered h-48" />
              </div>

              <div class="form-control mt-4">
                <label class="label">
                  <span class="label-text">Thumbnail URL</span>
                </label>
                <.input field={@form[:thumbnail_url]} type="url" class="input input-bordered" />
              </div>

              <div class="card-actions justify-end mt-6">
                <.link navigate={~p"/resources"} class="btn btn-ghost">
                  Cancel
                </.link>
                <button type="submit" class="btn btn-primary">
                  Save Resource
                </button>
              </div>
            </.form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp resource_type_options do
    [
      {"Website", "website"},
      {"Article", "article"},
      {"File", "file"},
      {"Directory", "directory"},
      {"Conversation", "conversation"},
      {"Other", "other"}
    ]
  end
end
