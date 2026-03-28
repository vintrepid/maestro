defmodule MaestroWeb.ProjectFormLive do
  use MaestroWeb, :live_view
  alias Maestro.Ops.Project

  @impl true
  def mount(params, _session, socket) do
    project =
      if params["slug"] do
        Maestro.Ops.get_project_by_slug(params["slug"])
      end

    form =
      if project do
        AshPhoenix.Form.for_update(project, :update, authorize?: false)
      else
        AshPhoenix.Form.for_create(Project, :create, authorize?: false)
      end

    {:ok,
     socket
     |> assign(:page_title, if(project, do: "Edit Project", else: "New Project"))
     |> assign(:project, project)
     |> assign(:form, to_form(form))}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form =
      socket.assigns.form.source
      |> AshPhoenix.Form.validate(params)

    {:noreply, assign(socket, :form, to_form(form))}
  end

  def handle_event("save", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form.source, params: params, authorize?: false) do
      {:ok, project} ->
        {:noreply,
         socket
         |> put_flash(:info, if(socket.assigns.project, do: "Project updated", else: "Project created"))
         |> push_navigate(to: ~p"/projects/#{project.slug}")}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={assigns[:current_user]}>
      <div class="max-w-2xl mx-auto">
        <h1 class="text-2xl font-bold mb-6">{@page_title}</h1>

        <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-4">
          <div class="grid grid-cols-2 gap-4">
            <.input field={@form[:name]} type="text" label="Name" required />
            <.input field={@form[:slug]} type="text" label="Slug" required />
          </div>

          <.input field={@form[:description]} type="textarea" label="Description" />

          <div class="grid grid-cols-2 gap-4">
            <.input field={@form[:web_port]} type="number" label="Web Port" required />
            <.input field={@form[:debugger_port]} type="number" label="Debugger Port" />
          </div>

          <.input field={@form[:github_url]} type="text" label="GitHub URL" />

          <div class="flex justify-end gap-3 pt-4">
            <.link navigate={~p"/projects"} class="btn btn-ghost">
              Cancel
            </.link>
            <button type="submit" class="btn btn-primary">
              {if @project, do: "Update Project", else: "Create Project"}
            </button>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end
end
