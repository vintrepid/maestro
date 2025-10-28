defmodule MaestroWeb.TaskFormLive do
  use MaestroWeb, :live_view
  alias Maestro.Ops.Task

  @impl true
  def mount(params, _session, socket) do
    task = if params["id"] do
      Task.by_id!(params["id"], load: [:display_name])
    else
      nil
    end

    form = if task do
      AshPhoenix.Form.for_update(task, :update)
    else
      initial_params = %{}
      initial_params = if params["entity_type"], do: Map.put(initial_params, :entity_type, params["entity_type"]), else: initial_params
      initial_params = if params["entity_id"], do: Map.put(initial_params, :entity_id, params["entity_id"]), else: initial_params
      
      AshPhoenix.Form.for_create(Task, :create, params: initial_params)
    end
    
    entity_name = if task do
      get_entity_name(task.entity_type, task.entity_id)
    else
      get_entity_name(params["entity_type"], params["entity_id"])
    end

    {:ok,
     socket
     |> assign(:page_title, if(task, do: "Edit Task", else: "New Task"))
     |> assign(:task, task)
     |> assign(:entity_name, entity_name)
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
      {:ok, _task} ->
        {:noreply,
         socket
         |> put_flash(:info, "Task saved successfully")
         |> push_navigate(to: ~p"/tasks")}
      
      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  def handle_event("run_task", _params, socket) do
    task = socket.assigns.task
    
    if task do
      Maestro.Ops.AppState.set_current_task(task.id)
      
      entity_project = if task.entity_type == "Project" do
        case Maestro.Repo.get(Maestro.Ops.Project, task.entity_id) do
          nil -> nil
          project -> project
        end
      else
        nil
      end
      
      if entity_project do
        Maestro.Ops.AppState.set_current_project(entity_project.id)
      end
      
      {:noreply,
       socket
       |> put_flash(:info, "Task #{task.title} is now active")
       |> push_navigate(to: ~p"/")}
    else
      {:noreply, put_flash(socket, :error, "Cannot run unsaved task")}
    end
  end

  def handle_event("mark_complete", _params, socket) do
    task = socket.assigns.task
    
    if task do
      case Task.mark_complete(task) do
        {:ok, updated_task} ->
          form = AshPhoenix.Form.for_update(updated_task, :update)
          
          {:noreply,
           socket
           |> assign(:task, updated_task)
           |> assign(:form, to_form(form))
           |> put_flash(:info, "Task marked as complete")}
        
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to mark task as complete")}
      end
    else
      {:noreply, put_flash(socket, :error, "Cannot mark unsaved task as complete")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="max-w-2xl mx-auto px-8 py-12">
        <div class="mb-8">
          <h2 class="text-2xl font-semibold">{if @task, do: @task.display_name, else: if(@entity_name, do: "#{@entity_name} - New Task", else: @page_title)}</h2>
        </div>

        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <.form for={@form} phx-change="validate" phx-submit="save">
              <%= if @entity_name do %>
                <h3 class="text-xl font-extrabold mb-4">
                  <.icon name="hero-folder" class="w-5 h-5 inline" />
                  {@entity_name}
                </h3>
              <% end %>
              
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
                  <.input field={@form[:task_type]} type="select" options={task_type_options()} class="select select-bordered" />
                </div>

                <div class="form-control">
                  <label class="label">
                    <span class="label-text">Status</span>
                  </label>
                  <.input field={@form[:status]} type="select" options={status_options()} class="select select-bordered" />
                </div>
              </div>

              <%= if @task && @task.completed_at do %>
                <div class="alert alert-success mt-4">
                  <.icon name="hero-check-circle" class="w-5 h-5" />
                  <span>Completed on {Calendar.strftime(@task.completed_at, "%B %d, %Y at %I:%M %p")}</span>
                </div>
              <% else %>
                <div class="form-control mt-4">
                  <label class="label">
                    <span class="label-text">Due Date</span>
                  </label>
                  <.input field={@form[:due_at]} type="datetime-local" class="input input-bordered" />
                </div>
              <% end %>

              <div class="form-control mt-4">
                <label class="label">
                  <span class="label-text">Description</span>
                </label>
                <div id="markdown-editor-wrapper" phx-update="ignore"><textarea id="markdown-editor" name="form[description]" phx-hook="MarkdownEditorHook" class="textarea textarea-bordered">{Phoenix.HTML.Form.input_value(@form, :description)}</textarea></div>
              </div>

              <div class="form-control mt-4">
                <label class="label">
                  <span class="label-text">Notes</span>
                </label>
                <div id="notes-markdown-editor-wrapper" phx-update="ignore"><textarea id="notes-markdown-editor" name="form[notes]" phx-hook="MarkdownEditorHook" class="textarea textarea-bordered">{Phoenix.HTML.Form.input_value(@form, :notes)}</textarea></div>
                
                <%= if @task && @task.notes do %>
                  <div class="mt-4 p-4 bg-base-200 rounded-lg prose prose-sm max-w-none">
                    <div class="text-xs text-base-content/60 mb-2">Rendered Preview:</div>
                    {raw(Earmark.as_html!(@task.notes))}
                  </div>
                <% end %>
              </div>

              <%= if is_nil(@task) do %>
                <div class="grid grid-cols-2 gap-4 mt-4">
                  <div class="form-control">
                    <label class="label">
                      <span class="label-text">Entity Type</span>
                    </label>
                    <.input field={@form[:entity_type]} type="select" options={entity_type_options()} class="select select-bordered" required />
                  </div>

                  <div class="form-control">
                    <label class="label">
                      <span class="label-text">Entity ID</span>
                    </label>
                    <.input field={@form[:entity_id]} type="text" class="input input-bordered" required />
                  </div>
                </div>
              <% end %>

              <div class="card-actions justify-end mt-6">
                <.link navigate={~p"/tasks"} class="btn btn-ghost">
                  Cancel
                </.link>
                <%= if @task do %>
                  <%= if @task.status != :done do %>
                    <button type="button" phx-click="mark_complete" class="btn btn-success gap-2">
                      <.icon name="hero-check-circle" class="w-5 h-5" />
                      Mark Complete
                    </button>
                  <% end %>
                  <button type="button" phx-click="run_task" class="btn btn-accent gap-2">
                    <.icon name="hero-play" class="w-5 h-5" />
                    Run Task
                  </button>
                <% end %>
                <button type="submit" class="btn btn-primary">
                  Save Task
                </button>
              </div>
            </.form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp task_type_options do
    [
      {"Feature", :feature},
      {"Bug", :bug},
      {"Refactor", :refactor},
      {"Documentation", :documentation},
      {"Other", :other}
    ]
  end

  defp status_options do
    [
      {"To Do", :todo},
      {"In Progress", :in_progress},
      {"Done", :done},
      {"Blocked", :blocked}
    ]
  end

  defp entity_type_options do
    [
      {"Project", "Project"}
    ]
  end

  defp get_entity_name("Project", entity_id) when not is_nil(entity_id) do
    case Maestro.Repo.get(Maestro.Ops.Project, entity_id) do
      nil -> nil
      project -> project.name
    end
  end
  
  defp get_entity_name(_, _), do: nil
end
