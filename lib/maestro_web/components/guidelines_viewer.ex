defmodule MaestroWeb.Components.GuidelinesViewer do
  use MaestroWeb, :html

  attr :class, :string, default: nil
  attr :project, :string, default: nil

  def guidelines_viewer(assigns) do
    project = assigns[:project] || get_project_name()
    assigns = assign(assigns, :startup_sequence, get_startup_sequence(project))
    assigns = assign(assigns, :agents_tree, get_agents_tree())

    ~H"""
    <.card class={@class}>
      <div class="text-xs font-bold text-primary mb-2">🚀 Agent Startup Sequence</div>
      <div class="text-xs text-base-content/70 mb-3">Read in this order each session:</div>
      <div id="startup-sequence" phx-hook="SortableHook" data-project={project}>
        <%= for {item, index} <- Enum.with_index(@startup_sequence, 1) do %>
          <.startup_item item={item} index={index} />
        <% end %>
      </div>

      <div class="text-xs font-bold text-accent mt-4 mb-2">📂 All Documentation</div>
      <%= for item <- @agents_tree do %>
        <.tree_item item={item} level={0} path_prefix="agents" />
      <% end %>
    </.card>
    """
  end

  attr :item, :map, required: true
  attr :index, :integer, required: true

  defp startup_item(assigns) do
    ~H"""
    <div
      class="flex items-start gap-2 py-1.5 hover:bg-base-200 rounded px-2 mb-1"
      data-path={@item.path}
    >
      <div class="drag-handle cursor-move">
        <.icon name="hero-bars-3" class="w-4 h-4 text-base-content/40" />
      </div>
      <input type="checkbox" checked class="checkbox checkbox-xs mt-0.5" />
      <div class="badge badge-primary badge-sm mt-0.5">{@index}</div>
      <div class="flex-1">
        <div
          class="flex items-center gap-2 cursor-pointer hover:underline"
          phx-click="open_file"
          phx-value-path={@item.path}
        >
          <.icon name="hero-document-text" class="w-3 h-3 text-primary" />
          <span class="text-xs font-semibold text-primary">{@item.name}</span>
        </div>
        <div class="text-xs text-base-content/60 ml-5">{@item.description}</div>
      </div>
    </div>
    """
  end

  attr :item, :map, required: true

  defp file_item(assigns) do
    ~H"""
    <div
      class="flex items-center gap-2 py-1 hover:bg-base-200 rounded px-2 cursor-pointer"
      phx-click="open_file"
      phx-value-path={get_file_path(@item.name)}
    >
      <input type="checkbox" checked={@item.checked} class="checkbox checkbox-xs" />
      <.icon name="hero-document-text" class="w-3 h-3 text-base-content/60" />
      <span class="text-xs">{@item.name}</span>
    </div>
    """
  end

  attr :item, :map, required: true
  attr :level, :integer, default: 0
  attr :path_prefix, :string, required: true

  defp tree_item(assigns) do
    assigns = assign(assigns, :current_path, Path.join(assigns.path_prefix, assigns.item.name))
    assigns = assign(assigns, :indent_class, case assigns.level do
      0 -> ""
      1 -> "pl-4"
      2 -> "pl-8"
      3 -> "pl-12"
      _ -> "pl-16"
    end)

    ~H"""
    <div class={@indent_class}>
      <%= if @item.type == :directory do %>
        <div class="flex items-center gap-2 py-1">
          <input type="checkbox" class="checkbox checkbox-xs" />
          <.icon name="hero-folder" class="w-4 h-4 text-warning" />
          <span class="text-xs font-semibold text-warning">{@item.name}/</span>
        </div>
        <%= for child <- @item.children do %>
          <.tree_item item={child} level={@level + 1} path_prefix={@current_path} />
        <% end %>
      <% else %>
        <div
          class="flex items-center gap-2 py-1 hover:bg-base-200 rounded px-2 cursor-pointer"
          phx-click="open_file"
          phx-value-path={@current_path}
        >
          <input type="checkbox" class="checkbox checkbox-xs" />
          <.icon name="hero-document-text" class="w-3 h-3 text-base-content/60" />
          <span class="text-xs">{@item.name}</span>
        </div>
      <% end %>
    </div>
    """
  end

  defp get_file_path(name) do
    cond do
      String.contains?(name, "(project root)") ->
        String.replace(name, " (project root)", "")

      String.ends_with?(name, ".md") ->
        "agents/project-specific/maestro/#{name}"

      true ->
        "agents/#{name}"
    end
  end

  defp get_startup_sequence(project) do
    
    [
      %{
        name: "AGENTS.md",
        path: "AGENTS.md",
        description: "Start here - project overview and initialization"
      },
      %{
        name: "agents/startup/STARTUP.md",
        path: "agents/startup/STARTUP.md",
        description: "Core startup instructions for all projects"
      },
      %{
        name: "agents/startup/#{String.upcase(project)}.md",
        path: "agents/startup/#{String.upcase(project)}.md",
        description: "Project-specific startup checklist"
      },
      %{
        name: "agents/GUIDELINES.md",
        path: "agents/GUIDELINES.md",
        description: "Git workflow, data migrations, verification"
      },
      %{
        name: "agents/LIVEVIEW.md",
        path: "agents/LIVEVIEW.md",
        description: "Elixir/Phoenix/LiveView technical patterns"
      },
      %{
        name: "agents/DAISYUI.md",
        path: "agents/DAISYUI.md",
        description: "DaisyUI component usage and patterns"
      }
    ]
  end

  defp get_project_name do
    Mix.Project.config()[:app] |> to_string()
  end

  defp get_agents_tree do
    agents_path = Path.join([File.cwd!(), "agents"])
    if File.exists?(agents_path) do
      build_directory_tree(agents_path)
    else
      []
    end
  end

  defp build_directory_tree(path) do
    File.ls!(path)
    |> Enum.reject(&String.starts_with?(&1, "."))
    |> Enum.sort()
    |> Enum.map(fn item ->
      item_path = Path.join(path, item)
      if File.dir?(item_path) do
        children = build_directory_tree(item_path)
        %{name: item, type: :directory, children: children}
      else
        %{name: item, type: :file}
      end
    end)
  end
end
