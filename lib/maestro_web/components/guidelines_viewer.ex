defmodule MaestroWeb.Components.GuidelinesViewer do
  use MaestroWeb, :html

  attr :class, :string, default: nil

  def guidelines_viewer(assigns) do
    assigns = assign(assigns, :project_guidelines, get_project_guidelines())
    assigns = assign(assigns, :fork_usage_rules, get_fork_usage_rules())
    assigns = assign(assigns, :package_usage_rules, get_package_usage_rules())
    assigns = assign(assigns, :agents_tree, get_agents_tree())

    ~H"""
    <.card class={@class}>
      <div class="text-xs font-bold text-primary">📋 Project Guidelines (Maestro)</div>
      <%= for item <- @project_guidelines do %>
        <.file_item item={item} />
      <% end %>

      <div class="text-xs font-bold text-success mt-3">🔧 Our Forks</div>
      <%= for item <- @fork_usage_rules do %>
        <.file_item item={item} />
      <% end %>

      <div class="text-xs font-bold text-secondary mt-3">📦 Package Usage Rules</div>
      <%= for item <- @package_usage_rules do %>
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

      String.contains?(name, "(our fork)") ->
        [fork_name, file] = name |> String.replace(" (our fork)", "") |> String.split("/")
        "../forks/#{fork_name}/#{file}"

      String.contains?(name, "/usage-rules.md") ->
        "deps/#{name}"

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

  defp get_fork_usage_rules do
    forks_base = Path.expand("~/dev/forks")
    [
      {"live_table", "usage_rules.md"},
      {"css_linter", "README.md"}
    ]
    |> Enum.map(fn {fork, doc_file} ->
      doc_path = Path.join([forks_base, fork, doc_file])
      if File.exists?(doc_path) do
        %{name: "#{fork}/#{doc_file} (our fork)", type: :file, checked: false}
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp get_package_usage_rules do
    deps_path = Path.join([File.cwd!(), "deps"])
    if File.exists?(deps_path) do
      File.ls!(deps_path)
      |> Enum.map(fn dep ->
        usage_rules = Path.join([deps_path, dep, "usage-rules.md"])
        if File.exists?(usage_rules) do
          %{name: "#{dep}/usage-rules.md", type: :file, checked: false}
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(& &1.name)
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
