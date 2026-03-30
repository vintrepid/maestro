defmodule Maestro.Ops.Rules.Bundler do
  @moduledoc """
  Generates agent-readable rule bundles from approved rules.

  Bundles are sized to fit within agent context windows:
  - Each bundle targets ~100 lines (agent read limit)
  - Rules are sorted by priority (highest first), then severity
  - Content is compact: one rule per line where possible

  Bundle types:
  - :universal — rules every agent must follow (architecture, security, workflow)
  - :ui — rules for UI/frontend builders (liveview, heex, css, components)
  - :model — rules for data model/backend builders (ash, elixir, security)
  - :devops — rules for deployment/ops tasks (testing, deployment, security)
  - :maestro — Maestro-specific rules (not exported to other projects)
  """

  import Ecto.Query
  alias Maestro.Repo

  @max_lines 95
  @bundle_categories %{
    universal: ~w(architecture security)a,
    ui: ~w(liveview heex css components forms routing pubsub)a,
    model: ~w(ash elixir security testing)a,
    devops: ~w(testing deployment security)a,
    maestro: :all
  }

  @doc """
  Generates all bundles and returns a map of bundle_name => content.
  """
  @spec generate_all() :: term()
  def generate_all do
    rules = fetch_approved_rules()

    Map.new([:universal, :ui, :model, :devops], fn bundle ->
      {bundle, generate_bundle(bundle, rules)}
    end)
  end

  @doc """
  Generates a single bundle as a compact string.
  """
  @spec generate_bundle(any(), any()) :: term()
  def generate_bundle(bundle_name, rules \\ nil) do
    rules = rules || fetch_approved_rules()

    # Filter by bundle assignment first, then fall back to category matching
    bundle_rules = filter_for_bundle(rules, bundle_name)

    # Sort: priority desc, then must > should > prefer
    sorted =
      bundle_rules
      |> Enum.sort_by(fn r -> {-r.priority, severity_rank(r.severity)} end)
      |> Enum.take(@max_lines)

    format_bundle(bundle_name, sorted)
  end

  @doc """
  Writes bundles to files in the given directory.
  Returns the list of files written.
  """
  @spec write_bundles(any()) :: term()
  def write_bundles(dir \\ ".") do
    bundles = generate_all()

    Enum.map(bundles, fn {name, content} ->
      path = Path.join(dir, "rules.#{name}.md")
      File.write!(path, content)
      path
    end)
  end

  @doc """
  Generates a compact rules.json with only essential fields,
  sized for agent consumption.
  """
  @spec generate_compact_json(any()) :: term()
  def generate_compact_json(bundle_name \\ :universal) do
    rules = fetch_approved_rules()
    bundle_rules = filter_for_bundle(rules, bundle_name)

    sorted =
      Enum.sort_by(bundle_rules, fn r -> {-r.priority, severity_rank(r.severity)} end)

    compact =
      Enum.map(sorted, fn r ->
        base = %{
          "id" => r.id,
          "category" => r.category,
          "severity" => r.severity,
          "content" => r.content
        }

        # Only include fix fields if present
        base
        |> maybe_put("fix_type", r.fix_type)
        |> maybe_put("fix_template", r.fix_template)
        |> maybe_put("fix_target", r.fix_target)
        |> maybe_put("fix_search", r.fix_search)
      end)

    Jason.encode!(compact, pretty: true)
  end

  # --- Private ---

  defp fetch_approved_rules do
    Enum.map(
      Repo.all(
        from r in "rules",
          where: r.status == "approved",
          select: %{
            id: type(r.id, :string),
            content: r.content,
            category: r.category,
            severity: r.severity,
            priority: r.priority,
            bundle: r.bundle,
            fix_type: r.fix_type,
            fix_template: r.fix_template,
            fix_target: r.fix_target,
            fix_search: r.fix_search
          },
          order_by: [desc: r.priority, asc: r.severity]
      ),
      fn r ->
        %{
          r
          | category: safe_to_atom(r.category),
            severity: safe_to_atom(r.severity),
            bundle: safe_to_atom(r.bundle || "universal")
        }
      end
    )
  end

  defp filter_for_bundle(rules, :maestro) do
    Enum.filter(rules, fn r -> r.bundle == :maestro end)
  end

  defp filter_for_bundle(rules, bundle_name) do
    categories = Map.get(@bundle_categories, bundle_name, [])

    Enum.filter(rules, fn r ->
      # Include if explicitly assigned to this bundle
      # Or if it's universal and categories match
      # Always include universal bundle rules in all bundles
      r.bundle == bundle_name or
        (r.bundle == :universal and r.category in categories) or
        (bundle_name != :universal and r.bundle == :universal and
           r.category in Map.get(@bundle_categories, :universal, []))
    end)
  end

  defp format_bundle(name, rules) do
    header =
      "# #{String.capitalize(to_string(name))} Rules\n# #{length(rules)} rules · Generated #{Date.utc_today()}\n\n"

    body =
      rules
      |> Enum.group_by(& &1.category)
      |> Enum.sort_by(fn {cat, _} -> to_string(cat) end)
      |> Enum.map(fn {category, cat_rules} ->
        section_header = "## #{String.capitalize(to_string(category))}\n"
        lines = Enum.map(cat_rules, &format_rule/1)
        section_header <> Enum.join(lines, "\n") <> "\n"
      end)
      |> Enum.join("\n")

    header <> body
  end

  defp format_rule(rule) do
    severity_tag = severity_tag(rule.severity)
    content = rule.content |> String.replace(~r/\n+/, " ") |> String.trim()
    "#{severity_tag} #{content}"
  end

  defp severity_tag(:must), do: "MUST:"
  defp severity_tag(:should), do: "SHOULD:"
  defp severity_tag(_), do: "PREFER:"

  defp severity_rank(:must), do: 0
  defp severity_rank(:should), do: 1
  defp severity_rank(_), do: 2

  defp safe_to_atom(nil), do: :universal
  defp safe_to_atom(val) when is_atom(val), do: val
  defp safe_to_atom(val) when is_binary(val), do: String.to_existing_atom(val)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)
end
