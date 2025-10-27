defmodule MaestroWeb.Components.GuidelinesViewer do
  use MaestroWeb, :html

  attr :project_guidelines, :list, required: true
  attr :fork_usage_rules, :list, required: true
  attr :package_usage_rules, :list, required: true
  attr :agents_tree, :list, required: true

  def guidelines_viewer(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-xl">
      <div class="card-body py-4">
        <div class="space-y-0.5">
          <div class="text-xs font-bold text-primary mb-1">📋 Project Guidelines (Maestro)</div>
          <%= for item <- @project_guidelines do %>
            <.file_item item={item} />
          <% end %>

          <div class="text-xs font-bold text-success mt-3 mb-1">🔧 Our Forks</div>
          <%= for item <- @fork_usage_rules do %>
            <.file_item item={item} />
          <% end %>

          <div class="text-xs font-bold text-secondary mt-3 mb-1">📦 Package Usage Rules</div>
          <%= for item <- @package_usage_rules do %>
            <.file_item item={item} />
          <% end %>

          <div class="text-xs font-bold text-accent mt-3 mb-1">📂 Agents Directory</div>
          <%= for item <- @agents_tree do %>
            <.tree_item item={item} level={0} />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  attr :item, :map, required: true

  defp file_item(assigns) do
    ~H"""
    <div
      class="flex items-center gap-1.5 py-0.5 hover:bg-base-200 rounded px-1 cursor-pointer"
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

  defp tree_item(assigns) do
    ~H"""
    <div style={"padding-left: #{@level * 1}rem"}>
      <%= if @item.type == :directory do %>
        <div class="flex items-center gap-1.5 py-0.5">
          <input type="checkbox" checked class="checkbox checkbox-xs" />
          <.icon name="hero-folder" class="w-4 h-4 text-warning" />
          <span class="text-xs font-semibold text-warning">{@item.name}/</span>
        </div>
        <%= for child <- @item.children do %>
          <.tree_item item={child} level={@level + 1} />
        <% end %>
      <% else %>
        <div class="flex items-center gap-1.5 py-0.5">
          <input type="checkbox" checked class="checkbox checkbox-xs" />
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
end
