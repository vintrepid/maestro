defmodule MaestroWeb.ConceptsLive do
  @moduledoc """
  Concept map of approved rules, visualized as a Mermaid diagram.

  Shows rules grouped by bundle (universal/ui/model) and category,
  with tag-based relationships between rules. Generated from the
  Rules DB — always reflects current approved state.
  """

  use MaestroWeb, :live_view

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    rules = load_rules()
    mermaid = build_mermaid(rules)

    {:ok,
     socket
     |> assign(:page_title, "Concepts")
     |> assign(:rules, rules)
     |> assign(:mermaid, mermaid)
     |> assign(:stats, build_stats(rules))}
  end

  @impl true
  @spec handle_params(map(), String.t(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="max-w-7xl mx-auto px-4 py-6">
        <div class="flex items-center justify-between mb-6">
          <h1 class="text-3xl font-bold">Rules Concept Map</h1>
          <div class="flex gap-2 text-sm">
            <span class="badge badge-primary">{@stats.total} rules</span>
            <span class="badge badge-ghost">{@stats.categories} categories</span>
            <span class="badge badge-ghost">{@stats.bundles} bundles</span>
            <span class="badge badge-ghost">{@stats.tags} tags</span>
          </div>
        </div>

        <div class="card bg-base-100 shadow-xl mb-6">
          <div class="card-body p-4 overflow-x-auto">
            <div id="mermaid-container" phx-hook="Mermaid" data-mermaid={@mermaid}>
              <pre class="mermaid">{@mermaid}</pre>
            </div>
          </div>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div :for={{bundle, rules} <- group_by_bundle(@rules)} class="card bg-base-100 shadow">
            <div class="card-body p-4">
              <h3 class="card-title text-sm">
                <span class={"badge #{bundle_class(bundle)}"}>{bundle || "unbundled"}</span>
                <span class="text-xs opacity-50">{length(rules)} rules</span>
              </h3>
              <ul class="text-xs space-y-1 mt-2">
                <li :for={rule <- rules} class="flex items-start gap-2">
                  <span class={"badge badge-xs #{severity_class(rule.severity)} mt-0.5"}>
                    {rule.severity}
                  </span>
                  <span class="truncate opacity-80">{truncate(rule.content, 60)}</span>
                </li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp load_rules do
    Maestro.Ops.Rule.approved!(authorize?: false)
    |> Enum.sort_by(fn r -> {r.category, -(r.severity || 0)} end)
    |> Enum.map(fn r ->
      %{
        id: r.id,
        category: r.category,
        bundle: r.bundle,
        severity: r.severity,
        tags: r.tags,
        content: r.content
      }
    end)
  end

  defp build_stats(rules) do
    %{
      total: length(rules),
      categories: rules |> Enum.map(& &1.category) |> Enum.uniq() |> length(),
      bundles: rules |> Enum.map(& &1.bundle) |> Enum.uniq() |> length(),
      tags: rules |> Enum.flat_map(&(&1.tags || [])) |> Enum.uniq() |> length()
    }
  end

  defp build_mermaid(rules) do
    by_bundle = Enum.group_by(rules, & &1.bundle)

    bundle_sections =
      Enum.map_join(by_bundle, "\n", fn {bundle, bundle_rules} ->
        bundle_name = bundle || "unbundled"
        safe_bundle = safe_id(bundle_name)

        by_category = Enum.group_by(bundle_rules, & &1.category)

        category_nodes =
          Enum.map_join(by_category, "\n", fn {category, cat_rules} ->
            safe_cat = safe_id("#{bundle_name}_#{category}")
            rule_count = length(cat_rules)
            severities = cat_rules |> Enum.map(& &1.severity) |> Enum.frequencies()
            must_count = Map.get(severities, "must", 0)
            should_count = Map.get(severities, "should", 0)
            label = "#{category}\\n#{must_count} must, #{should_count} should"
            "    #{safe_cat}[\"#{label}\"]"
          end)

        connections =
          Enum.map_join(by_category, "\n", fn {category, _} ->
            safe_cat = safe_id("#{bundle_name}_#{category}")
            "    #{safe_bundle} --> #{safe_cat}"
          end)

        """
            #{safe_bundle}{{\"#{bundle_name}\\n#{length(bundle_rules)} rules\"}}
        #{category_nodes}
        #{connections}
        """
      end)

    # Tag-based connections between categories across bundles
    tag_connections = build_tag_connections(rules)

    """
    graph TD
    #{bundle_sections}
    #{tag_connections}
    """
  end

  defp build_tag_connections(rules) do
    # Group rules by tags, find tags that span multiple categories
    rules
    |> Enum.flat_map(fn rule ->
      Enum.map(rule.tags || [], fn tag ->
        {tag, "#{rule.bundle || "unbundled"}_#{rule.category}"}
      end)
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.filter(fn {_tag, categories} -> length(Enum.uniq(categories)) > 1 end)
    |> Enum.map_join("\n", fn {tag, categories} ->
      cats = Enum.uniq(categories)
      [first | rest] = cats

      Enum.map_join(rest, "\n", fn cat ->
        "    #{safe_id(first)} -.-|#{tag}| #{safe_id(cat)}"
      end)
    end)
  end

  defp group_by_bundle(rules) do
    rules
    |> Enum.group_by(& &1.bundle)
    |> Enum.sort_by(fn {bundle, _} -> bundle || "zzz" end)
  end

  defp safe_id(str) do
    str
    |> to_string()
    |> String.replace(~r/[^a-zA-Z0-9]/, "_")
    |> String.trim("_")
  end

  defp truncate(nil, _), do: ""
  defp truncate(str, max) when byte_size(str) <= max, do: str
  defp truncate(str, max), do: String.slice(str, 0, max) <> "..."

  defp bundle_class("universal"), do: "badge-primary"
  defp bundle_class("ui"), do: "badge-secondary"
  defp bundle_class("model"), do: "badge-accent"
  defp bundle_class("maestro"), do: "badge-info"
  defp bundle_class(_), do: "badge-ghost"

  defp severity_class("must"), do: "badge-error"
  defp severity_class("should"), do: "badge-warning"
  defp severity_class(_), do: "badge-ghost"
end
