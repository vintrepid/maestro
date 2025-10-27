defmodule MaestroWeb.Components.GuidelinesViewer do
  use MaestroWeb, :html

  attr :class, :string, default: nil

  def guidelines_viewer(assigns) do
    assigns = assign(assigns, :project_guidelines, get_project_guidelines())
    assigns = assign(assigns, :usage_rules, get_usage_rules())
    assigns = assign(assigns, :agents_tree, get_agents_tree())

    ~H"""
    <.card class={@class}>
      <div class="text-xs font-bold text-primary">📋 Project Guidelines (Maestro)</div>
      <%= for item <- @project_guidelines do %>
        <.file_item item={item} />
      <% end %>

      <div class="text-xs font-bold text-success mt-3">📚 Usage Rules (Tools & Packages)</div>
      <%= for item <- @usage_rules do %>
        <.file_item item={item} />
      <% end %>

      <div class="text-xs font-bold text-accent mt-3">📂 Agents Directory</div>
      <%= for item <- @agents_tree do %>
        <.tree_item item={item} level={0} path_prefix="agents" />
      <% end %>
    </.card>
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

      String.contains?(name, "(usage_rules)") ->
        tool = name |> String.replace(" (usage_rules)", "")
        "agents/usage_rules/#{tool}.md"

      String.ends_with?(name, ".md") ->
        "agents/project-specific/maestro/#{name}"

      true ->
        "agents/#{name}"
    end
  end

  defp get_project_guidelines do
    root_files = ["AGENTS.md", "REFACTORING_NOTES.md"]
    root_items = root_files
    |> Enum.map(fn file ->
      path = Path.join([File.cwd!(), file])
      if File.exists?(path) do
        %{name: "#{file} (project root)", type: :file, checked: false}
      end
    end)
    |> Enum.reject(&is_nil/1)

    project_path = Path.join([File.cwd!(), "agents", "project-specific", "maestro"])
    maestro_items = if File.exists?(project_path) do
      File.ls!(project_path)
      |> Enum.reject(&String.starts_with?(&1, "."))
      |> Enum.sort()
      |> Enum.map(&%{name: &1, type: :file, checked: false})
    else
      []
    end

    root_items ++ maestro_items
  end

  defp get_usage_rules do
    usage_rules_path = Path.join([File.cwd!(), "agents", "usage_rules"])
    if File.exists?(usage_rules_path) do
      File.ls!(usage_rules_path)
      |> Enum.reject(&(&1 == "README.md"))
      |> Enum.reject(&String.starts_with?(&1, "."))
      |> Enum.sort()
      |> Enum.map(fn file ->
        tool_name = String.replace(file, ".md", "")
        %{name: "#{tool_name} (usage_rules)", type: :file, checked: false}
      end)
    else
      []
    end
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
