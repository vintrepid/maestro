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
     |> assign(:editing_notes, false)
     |> assign(:editing_description, false)
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
    is_new_task = socket.assigns.task == nil
    
    case AshPhoenix.Form.submit(form, params: params) do
      {:ok, task} ->
        if is_new_task do
          {:noreply,
           socket
           |> put_flash(:info, "Task created successfully")
           |> push_navigate(to: ~p"/tasks/#{task.id}/edit")}
        else
          task = Task.by_id!(task.id, load: [:display_name])
          form = AshPhoenix.Form.for_update(task, :update)
          
          {:noreply,
           socket
           |> assign(:task, task)
           |> assign(:form, to_form(form))
           |> assign(:editing_notes, false)
           |> assign(:editing_description, false)
           |> put_flash(:info, "Task saved successfully")}
        end
      
      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  def handle_event("edit_notes", _params, socket) do
    {:noreply, assign(socket, :editing_notes, true)}
  end

  def handle_event("cancel_edit_notes", _params, socket) do
    {:noreply, assign(socket, :editing_notes, false)}
  end

  def handle_event("edit_description", _params, socket) do
    {:noreply, assign(socket, :editing_description, true)}
  end

  def handle_event("cancel_edit_description", _params, socket) do
    {:noreply, assign(socket, :editing_description, false)}
  end

  def handle_event("run_task", _params, socket) do
    task = socket.assigns.task
    
    if task do
      entity_project = if task.entity_type == "Project" do
        case Maestro.Repo.get(Maestro.Ops.Project, task.entity_id) do
          nil -> nil
          project -> project
        end
      else
        nil
      end
      
      if entity_project do
        project_path = Path.expand("~/dev/#{entity_project.slug}")
        
        if File.dir?(project_path) do
          Maestro.Ops.AppState.set_current_task(task.id)
          Maestro.Ops.AppState.set_current_project(entity_project.id)
          
          case System.cmd("mix", ["maestro.task.request", to_string(task.id), project_path], stderr_to_stdout: true) do
            {output, 0} ->
              {:noreply,
               socket
               |> put_flash(:info, "Task coordinated successfully! Check #{entity_project.name} project.")}
            
            {output, _} ->
              {:noreply,
               socket
               |> put_flash(:error, "Failed to coordinate task: #{String.slice(output, 0..200)}...")}
          end
        else
          {:noreply,
           socket
           |> put_flash(:error, "Project directory not found: #{project_path}")}
        end
      else
        {:noreply,
         socket
         |> put_flash(:error, "Task must belong to a Project to be run. This task belongs to #{task.entity_type}.")}
      end
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
      <div class="w-full px-4 py-2">
        <div class="mb-2">
          <div class="text-sm font-medium text-base-content/70">{if @task, do: @task.display_name, else: if(@entity_name, do: "#{@entity_name} - New Task", else: @page_title)}</div>
        </div>

        <div class="card bg-base-100 shadow-sm">
          <div class="card-body p-3">
            <.form for={@form} phx-change="validate" phx-submit="save">
              <%= if @entity_name do %>
                <div class="text-xs font-semibold mb-2 text-base-content/60">
                  <.icon name="hero-folder" class="w-3 h-3 inline" />
                  {@entity_name}
                </div>
              <% end %>
              
              <div class="flex gap-2 mb-1 items-center">
                <div class="flex-1">
                  <.input field={@form[:title]} type="text" class="input input-bordered input-sm" placeholder="Title" required />
                </div>
                <div class="w-36">
                  <.input field={@form[:task_type]} type="select" options={task_type_options()} class="select select-bordered select-sm" />
                </div>
                <div class="w-36">
                  <.input field={@form[:status]} type="select" options={status_options()} class="select select-bordered select-sm" />
                </div>
              </div>

              <%= if @task && @task.completed_at do %>
                <div class="text-xs text-success mb-2">
                  <.icon name="hero-check-circle" class="w-3 h-3 inline" />
                  <span>Completed {Calendar.strftime(@task.completed_at, "%m/%d/%y %I:%M%p")}</span>
                </div>
              <% end %>

              <%= if @task do %>
                <div class="grid grid-cols-2 gap-2 mb-1">
                  <div>
                <%= if @editing_description do %>
                  <div class="mt-6 p-4 bg-base-200 rounded-lg">
                    <div class="flex items-center justify-between mb-2">
                      <div class="text-sm font-semibold uppercase tracking-wide">Edit Description</div>
                      <button type="button" phx-click="cancel_edit_description" class="btn btn-ghost btn-xs">
                        <.icon name="hero-x-mark" class="w-4 h-4" />
                        Cancel
                      </button>
                    </div>
                    <div id="description-markdown-editor-wrapper" phx-update="ignore"><textarea id="description-markdown-editor" name="form[description]" phx-hook="MarkdownEditorHook" class="textarea textarea-bordered">{Phoenix.HTML.Form.input_value(@form, :description)}</textarea></div>
                  </div>
                <% else %>
                  <%= if @task.description do %>
                    <div class="p-2 bg-base-200 rounded cursor-pointer hover:bg-base-300 max-h-40 overflow-y-auto" phx-click="edit_description">
                      <div class="flex items-center justify-between mb-0.5">
                        <div class="text-xs text-base-content/60 font-semibold">Description</div>
                        <.icon name="hero-pencil" class="w-3 h-3 text-base-content/40" />
                      </div>
                      <div class="prose prose-sm max-w-none compact-prose">{raw(Earmark.as_html!(@task.description))}</div>
                    </div>
                  <% else %>
                    <button type="button" phx-click="edit_description" class="mt-6 w-full p-4 bg-base-200 rounded-lg hover:bg-base-300 transition-colors text-left">
                      <div class="flex items-center gap-2 text-base-content/60">
                        <.icon name="hero-plus" class="w-5 h-5" />
                        <span>Add description...</span>
                      </div>
                    </button>
                  <% end %>
                <% end %>
                  </div>
                  <div>
                <%= if @editing_notes do %>
                  <div class="p-2 bg-base-200 rounded">
                    <div class="flex items-center justify-between mb-1">
                      <div class="text-xs font-semibold">Notes</div>
                      <button type="button" phx-click="cancel_edit_notes" class="btn btn-ghost btn-xs">
                        <.icon name="hero-x-mark" class="w-3 h-3" />
                      </button>
                    </div>
                    <div id="notes-markdown-editor-wrapper" phx-update="ignore"><textarea id="notes-markdown-editor" name="form[notes]" phx-hook="MarkdownEditorHook" class="textarea textarea-bordered textarea-sm h-40">{Phoenix.HTML.Form.input_value(@form, :notes)}</textarea></div>
                  </div>
                <% else %>
                  <%= if @task.notes do %>
                    <div class="p-2 bg-base-200 rounded cursor-pointer hover:bg-base-300 max-h-40 overflow-y-auto" phx-click="edit_notes">
                      <div class="flex items-center justify-between mb-0.5">
                        <div class="text-xs text-base-content/60 font-semibold">Notes</div>
                        <.icon name="hero-pencil" class="w-3 h-3 text-base-content/40" />
                      </div>
                      <div class="prose prose-sm max-w-none compact-prose">{raw(Earmark.as_html!(@task.notes))}</div>
                    </div>
                  <% else %>
                    <button type="button" phx-click="edit_notes" class="w-full p-2 bg-base-200 rounded hover:bg-base-300 text-left">
                      <div class="flex items-center gap-1 text-base-content/60 text-xs">
                        <.icon name="hero-plus" class="w-3 h-3" />
                        <span>Add notes...</span>
                      </div>
                    </button>
                  <% end %>
                <% end %>
                  </div>
                </div>

              <% else %>
                <div class="form-control mt-4">
                  <label class="label">
                    <span class="label-text">Description (optional)</span>
                  </label>
                  <div id="description-markdown-editor-wrapper" phx-update="ignore"><textarea id="description-markdown-editor" name="form[description]" phx-hook="MarkdownEditorHook" class="textarea textarea-bordered">{Phoenix.HTML.Form.input_value(@form, :description)}</textarea></div>
                </div>
              <% end %>

              <%= if @task do %>
                <div class="mt-1">
                  <div class="flex items-center justify-between mb-1">
                    <div class="text-xs font-semibold text-base-content/70">Sub-tasks</div>
                    <.link navigate={~p"/tasks/new?entity_type=Task&entity_id=#{@task.id}"} class="btn btn-xs btn-primary">
                      <.icon name="hero-plus" class="w-3 h-3" />
                      New
                    </.link>
                  </div>
                  <MaestroWeb.Components.TaskTable.task_table
                    id="task-subtasks-table"
                    query_fn={fn -> task_subtasks_query(@task.id) end}
                  />
                </div>
              <% end %>

              <%= if @task do %>
                <%= if @editing_notes do %>
                  <div class="mt-6 p-4 bg-base-200 rounded-lg">
                    <div class="flex items-center justify-between mb-2">
                      <div class="text-sm font-semibold uppercase tracking-wide">Edit Notes</div>
                      <button type="button" phx-click="cancel_edit_notes" class="btn btn-ghost btn-xs">
                        <.icon name="hero-x-mark" class="w-4 h-4" />
                        Cancel
                      </button>
                    </div>
                    <div id="notes-markdown-editor-wrapper" phx-update="ignore"><textarea id="notes-markdown-editor" name="form[notes]" phx-hook="MarkdownEditorHook" class="textarea textarea-bordered">{Phoenix.HTML.Form.input_value(@form, :notes)}</textarea></div>
                  </div>
                <% else %>
                  <%= if @task.notes do %>
                    <div class="mt-2 p-3 bg-base-200 rounded prose prose-sm max-w-none cursor-pointer hover:bg-base-300 transition-colors compact-prose" phx-click="edit_notes">
                      <div class="flex items-center justify-between mb-1">
                        <div class="text-xs text-base-content/60 font-semibold">Notes</div>
                        <.icon name="hero-pencil" class="w-3 h-3 text-base-content/40" />
                      </div>
                      {raw(Earmark.as_html!(@task.notes))}
                    </div>
                  <% else %>
                    <button type="button" phx-click="edit_notes" class="mt-6 w-full p-4 bg-base-200 rounded-lg hover:bg-base-300 transition-colors text-left">
                      <div class="flex items-center gap-2 text-base-content/60">
                        <.icon name="hero-plus" class="w-5 h-5" />
                        <span>Add notes...</span>
                      </div>
                    </button>
                  <% end %>
                <% end %>
              <% end %>

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

              <div class="flex justify-end gap-2 mt-2">
                <.link navigate={~p"/tasks"} class="btn btn-ghost btn-sm">
                  Cancel
                </.link>
                <%= if @task do %>
                  <%= if @task.status != :done do %>
                    <button type="button" phx-click="mark_complete" class="btn btn-success btn-sm gap-1">
                      <.icon name="hero-check-circle" class="w-3 h-3" />
                      Complete
                    </button>
                  <% end %>
                  <%= if @task.entity_type == "Project" do %>
                    <button type="button" phx-click="run_task" class="btn btn-accent btn-sm gap-1" title="Coordinates this task using mix maestro.task.request">
                      <.icon name="hero-play" class="w-3 h-3" />
                      Run
                    </button>
                  <% else %>
                    <div class="tooltip tooltip-left" data-tip="Only Project tasks can be run">
                      <button type="button" class="btn btn-disabled btn-sm gap-1">
                        <.icon name="hero-play" class="w-3 h-3" />
                        Run
                      </button>
                    </div>
                  <% end %>
                <% end %>
                <button type="submit" class="btn btn-primary btn-sm">
                  Save
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
      {"Project", "Project"},
      {"Task", "Task"}
    ]
  end

  defp get_entity_name("Project", entity_id) when not is_nil(entity_id) do
    case Maestro.Repo.get(Maestro.Ops.Project, entity_id) do
      nil -> nil
      project -> project.name
    end
  end
  
  defp get_entity_name("Task", entity_id) when not is_nil(entity_id) do
    case Task.by_id(entity_id) do
      {:ok, task} -> task |> Maestro.Ops.load!([:display_name]) |> Map.get(:display_name)
      _ -> nil
    end
  end
  
  defp get_entity_name(_, _), do: nil
  
  defp is_nil_or_empty(nil), do: true
  defp is_nil_or_empty(""), do: true
  defp is_nil_or_empty(_), do: false
  
  defp task_subtasks_query(task_id) do
    import Ecto.Query
    from t in Task,
      where: t.entity_type == "Task" and t.entity_id == ^to_string(task_id),
      order_by: [desc: t.inserted_at]
  end
end
