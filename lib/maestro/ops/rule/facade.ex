defmodule Maestro.Ops.Rule.Facade do
  @moduledoc """
  Facade over all rule domain operations used by the curation UI.

  This module is the single entry point for RulesLive. It encapsulates:

  - Loading and querying rules (by status, category, tag, source, bundle)
  - Mutation actions (approve, retire, mark_linter, mark_anti_pattern, destroy, update)
  - Quality auditing and gating (delegates to Quality)
  - Coverage stats (delegates to Coverage)
  - Priority auto-assignment (delegates to Prioritizer)
  - Tag cloud query (raw SQL for unnesting the tags array)
  - Category counts, status totals, bundle stats, source options

  LiveViews should alias this module and call its functions exclusively,
  keeping all Ash.Query / Ecto.Query / Repo usage here.
  """

  require Ash.Query
  import Ash.Query
  import Ecto.Query, only: [from: 2]
  import Phoenix.Component, only: [to_form: 1]

  alias Maestro.Ops.Rule
  alias Maestro.Ops.Rules.{Coverage, Quality, Prioritizer}

  # ---------------------------------------------------------------------------
  # Domain Enumerations
  # ---------------------------------------------------------------------------

  @spec status_options() :: term()
  def status_options do
    [
      {"Proposed", "proposed"},
      {"Approved", "approved"},
      {"Linter", "linter"},
      {"Anti-pattern", "anti_pattern"},
      {"Retired", "retired"}
    ]
  end

  @spec category_options() :: term()
  def category_options do
    [
      {"Architecture", "architecture"},
      {"Ash", "ash"},
      {"Components", "components"},
      {"CSS", "css"},
      {"Elixir", "elixir"},
      {"Forms", "forms"},
      {"HEEx", "heex"},
      {"LiveView", "liveview"},
      {"PubSub", "pubsub"},
      {"Routing", "routing"},
      {"Security", "security"},
      {"Testing", "testing"}
    ]
  end

  @spec bundle_options() :: term()
  def bundle_options do
    [
      {"Universal", "universal"},
      {"UI", "ui"},
      {"Model", "model"},
      {"DevOps", "devops"},
      {"Maestro", "maestro"}
    ]
  end

  # ---------------------------------------------------------------------------
  # Queries
  # ---------------------------------------------------------------------------

  @doc "Returns the default sorted query for the rules table."
  @spec default_query() :: Ash.Query.t()
  def default_query do
    sort(Rule, priority: :desc, category: :asc)
  end

  @doc "Returns a query sorted by priority descending (no filters)."
  @spec sorted_query() :: Ash.Query.t()
  def sorted_query do
    sort(Rule, priority: :desc)
  end

  @doc "Returns a query filtered to a specific tag, sorted by priority."
  @spec query_by_tag(String.t()) :: Ash.Query.t()
  def query_by_tag(tag) do
    Rule
    |> filter(fragment("? @> ARRAY[?]::text[]", tags, ^tag))
    |> sort(priority: :desc)
  end

  @doc "Returns a query filtered to a specific category, sorted by priority."
  @spec query_by_category(String.t()) :: Ash.Query.t()
  def query_by_category(category) do
    Rule |> filter(category == ^category) |> sort(priority: :desc)
  end

  @doc "Returns a query filtered to a specific source project slug."
  @spec query_by_source(String.t()) :: Ash.Query.t()
  def query_by_source(source) do
    Rule |> filter(source_project_slug == ^source) |> sort(updated_at: :desc)
  end

  @doc "Returns a query filtered to a specific source AND status."
  @spec query_by_source_status(String.t(), atom()) :: Ash.Query.t()
  def query_by_source_status(source, status) do
    Rule
    |> filter(source_project_slug == ^source and status == ^status)
    |> sort(updated_at: :desc)
  end

  # ---------------------------------------------------------------------------
  # Mutations
  # ---------------------------------------------------------------------------

  @doc "Approves a rule if it passes quality checks. Returns :ok or {:error, reason}."
  @spec approve_rule(String.t()) :: :ok | {:error, String.t()}
  def approve_rule(id) do
    rule = Rule.by_id!(id)

    if Quality.passes_quality?(rule) do
      {:ok, rule} = Rule.approve(rule)
      request_curation(rule, :approved, "Approved — verify bundle, category, tags, and check for duplicates to supersede")
      :ok
    else
      {:error, "Rule fails quality checks — fix content before approving"}
    end
  end

  @doc "Retires a rule with a default reason."
  @spec retire_rule(String.t(), String.t()) :: :ok | {:ok, term()}
  def retire_rule(id, reason \\ "Retired from UI") do
    rule = Rule.by_id!(id)
    result = Rule.retire(rule, %{retired_reason: reason})
    request_curation(rule, :retired, "Retired — find canonical rule and link via superseded_by")
    result
  end

  @doc "Marks a rule as a linter rule."
  @spec mark_linter(String.t()) :: :ok | {:ok, term()}
  def mark_linter(id) do
    rule = Rule.by_id!(id)
    result = Rule.mark_linter(rule)
    request_curation(rule, :linter, "Marked linter — design igniter/mix task to enforce this rule automatically")
    result
  end

  @doc "Marks a rule as an anti-pattern."
  @spec mark_anti_pattern(String.t()) :: :ok | {:ok, term()}
  def mark_anti_pattern(id) do
    rule = Rule.by_id!(id)
    result = Rule.mark_anti_pattern(rule)
    request_curation(rule, :anti_pattern, "Marked anti-pattern — find canonical rule, link via superseded_by, extract curation insight")
    result
  end

  @doc """
  Loads a rule by id with relationships and related rules for the detail page.

  Returns `{rule, related}` where related is a map with:
  - `:superseded_by` — the rule this one was superseded by (or nil)
  - `:supersedes` — rules this one supersedes
  - `:same_category` — other rules in the same category (limit 10)
  - `:same_tags` — rules sharing tags (limit 10)
  - `:source` — rule_source and library
  """
  @spec get_rule_with_related(String.t()) :: {term(), map()}
  def get_rule_with_related(id) do
    rule = Rule.by_id!(id, authorize?: false, load: [:superseded_by, :supersedes, :library, :rule_source])

    same_category =
      Rule
      |> filter(category == ^rule.category and id != ^rule.id and status in [:approved, :proposed])
      |> sort(priority: :desc)
      |> Ash.read!(authorize?: false, page: [limit: 10])
      |> Map.get(:results, [])

    same_tags =
      if rule.tags != [] do
        all = Rule.read!(authorize?: false)
        |> Enum.filter(fn r ->
          r.id != rule.id and r.status in [:approved, :proposed] and
          Enum.any?(r.tags || [], &(&1 in (rule.tags || [])))
        end)
        |> Enum.sort_by(fn r -> -length((r.tags || []) -- (r.tags || [] -- (rule.tags || []))) end)
        |> Enum.take(10)
        all
      else
        []
      end

    related = %{
      superseded_by: rule.superseded_by,
      supersedes: rule.supersedes,
      same_category: same_category,
      same_tags: same_tags
    }

    {rule, related}
  end

  @doc "Destroys a rule by id."
  @spec destroy_rule(String.t()) :: :ok | {:ok, term()}
  def destroy_rule(id) do
    Rule.destroy(Rule.by_id!(id))
  end

  @doc "Updates a rule with the given params."
  @spec update_rule(String.t(), map()) :: {:ok, term()} | {:error, term()}
  def update_rule(id, params) do
    Rule.update(Rule.by_id!(id), params)
  end

  @doc """
  Creates a discussion task linked to a rule.

  The task captures the rule's current state (content, status, notes) so that
  an agent can find and respond to it by querying discussion tasks.
  """
  @spec discuss_rule(String.t()) :: {:ok, term()} | {:error, term()}
  def discuss_rule(id) do
    rule = Rule.by_id!(id, authorize?: false)

    Maestro.Ops.Task.create(%{
      title: "Discuss: #{String.slice(rule.content, 0, 80)}",
      description: rule.content,
      notes: rule.notes,
      task_type: :discussion,
      status: :todo,
      entity_type: "rule",
      entity_id: rule.id
    }, authorize?: false)
  end

  @doc "Returns open discussion tasks for rules."
  @spec pending_discussions() :: [term()]
  def pending_discussions do
    pending_rule_tasks(:discussion)
  end

  @doc "Returns open curation tasks for rules."
  @spec pending_curations() :: [term()]
  def pending_curations do
    pending_rule_tasks(:curation)
  end

  @doc "Returns all pending rule tasks (discussions + curations)."
  @spec pending_rule_tasks() :: [term()]
  def pending_rule_tasks do
    Maestro.Ops.Task.read!(authorize?: false)
    |> Enum.filter(&(&1.task_type in [:discussion, :curation] and &1.status in [:todo, :in_progress] and &1.entity_type == "rule"))
    |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
  end

  defp pending_rule_tasks(type) do
    Maestro.Ops.Task.read!(authorize?: false)
    |> Enum.filter(&(&1.task_type == type and &1.status in [:todo, :in_progress] and &1.entity_type == "rule"))
    |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
  end

  @doc """
  Creates a curation task after a rule status change.

  The task captures the rule, the new status, and what curation work is needed.
  Agents pick these up to find related rules, link canonical patterns, and
  extract curation insights.
  """
  @spec request_curation(term(), atom(), String.t()) :: {:ok, term()}
  def request_curation(rule, new_status, instructions) do
    Maestro.Ops.Task.create(%{
      title: "Curate: #{String.slice(rule.content, 0, 60)}",
      description: "Rule #{String.slice(rule.id, 0, 8)} changed to #{new_status}.\n\n**Content:** #{rule.content}\n\n**Notes:** #{rule.notes}",
      notes: instructions,
      task_type: :curation,
      status: :todo,
      entity_type: "rule",
      entity_id: rule.id
    }, authorize?: false)
  end

  @doc "Returns an AshPhoenix form for creating a new rule."
  @spec new_form() :: Phoenix.HTML.Form.t()
  def new_form do
    to_form(AshPhoenix.Form.for_create(Rule, :create, as: "rule"))
  end

  @doc "Returns an AshPhoenix form for editing an existing rule."
  @spec edit_form(String.t()) :: {term(), Phoenix.HTML.Form.t()}
  def edit_form(id) do
    rule = Rule.by_id!(id, authorize?: false)
    form = to_form(AshPhoenix.Form.for_update(rule, :update, as: "rule"))
    {rule, form}
  end

  @doc "Validates a form with params, returns updated form."
  @spec validate_form(term(), map()) :: Phoenix.HTML.Form.t()
  def validate_form(form_source, params) do
    to_form(AshPhoenix.Form.validate(form_source, normalize_params(params)))
  end

  @doc "Submits a form. Returns {:ok, rule} or {:error, form}."
  @spec submit_form(term(), map()) :: {:ok, term()} | {:error, term()}
  def submit_form(form_source, params) do
    case AshPhoenix.Form.submit(form_source, params: normalize_params(params)) do
      {:ok, rule} -> {:ok, rule}
      {:error, form} -> {:error, to_form(form)}
    end
  end

  defp normalize_params(params) do
    case Map.get(params, "tags") do
      nil -> params
      tags when is_list(tags) -> params
      tags when is_binary(tags) ->
        Map.put(params, "tags", tags |> String.split(",", trim: true) |> Enum.map(&String.trim/1))
    end
  end

  @doc """
  Bulk-approves the given set of rule ids.
  Returns the count of successfully approved rules.
  """
  @spec bulk_approve(MapSet.t()) :: non_neg_integer()
  def bulk_approve(ids) do
    Enum.reduce(ids, 0, fn id, acc ->
      rule = Rule.by_id!(id)

      case Rule.approve(rule) do
        {:ok, _} -> acc + 1
        _ -> acc
      end
    end)
  end

  @doc """
  Bulk-retires the given set of rule ids.
  Returns the count of successfully retired rules.
  """
  @spec bulk_retire(MapSet.t()) :: non_neg_integer()
  def bulk_retire(ids) do
    Enum.reduce(ids, 0, fn id, acc ->
      rule = Rule.by_id!(id)

      case Rule.retire(rule, %{retired_reason: "Bulk retired from curation UI"}) do
        {:ok, _} -> acc + 1
        _ -> acc
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Quality
  # ---------------------------------------------------------------------------

  @doc "Runs a quality audit on all approved rules. Returns {summary, quality_by_id}."
  @spec quality_audit() :: {map(), map()}
  def quality_audit do
    results = Quality.audit_rules(Rule.approved!())
    summary = Quality.summarize(results)
    by_id = Map.new(results, &{&1.id, &1})
    {summary, by_id}
  end

  @doc "Returns whether a single rule passes quality checks."
  @spec passes_quality?(term()) :: boolean()
  defdelegate passes_quality?(rule), to: Quality

  # ---------------------------------------------------------------------------
  # Coverage
  # ---------------------------------------------------------------------------

  @doc "Returns coverage stats per library."
  @spec coverage_stats() :: {list(), list()}
  def coverage_stats do
    {Coverage.by_library(), Coverage.skills()}
  end

  # ---------------------------------------------------------------------------
  # Prioritizer
  # ---------------------------------------------------------------------------

  @doc "Auto-assigns priority scores to all approved rules. Returns {updated, skipped}."
  @spec auto_prioritize() :: {non_neg_integer(), non_neg_integer()}
  def auto_prioritize do
    Prioritizer.auto_assign_all()
  end

  # ---------------------------------------------------------------------------
  # Aggregate queries
  # ---------------------------------------------------------------------------

  @doc "Returns distinct source project slug options as {label, value} tuples."
  @spec source_options() :: [{String.t(), String.t()}]
  def source_options do
    Rule.read!()
    |> Enum.map(& &1.source_project_slug)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(&{&1, &1})
  end

  @doc "Returns bundle distribution stats for approved rules, sorted by count desc."
  @spec bundle_stats() :: [{String.t() | nil, non_neg_integer()}]
  def bundle_stats do
    Rule.approved!(authorize?: false)
    |> Enum.group_by(& &1.bundle)
    |> Enum.map(fn {bundle, rules} -> {bundle && to_string(bundle), length(rules)} end)
    |> Enum.sort_by(fn {_bundle, count} -> -count end)
  end

  @doc "Returns category counts for proposed rules, sorted by count desc."
  @spec category_counts() :: [{String.t() | nil, non_neg_integer()}]
  def category_counts do
    Rule.proposed!(authorize?: false)
    |> Enum.group_by(& &1.category)
    |> Enum.map(fn {category, rules} -> {category && to_string(category), length(rules)} end)
    |> Enum.sort_by(fn {_category, count} -> -count end)
  end

  @doc "Returns status totals across all rules as [{status_string, count}]."
  @spec status_totals() :: [{String.t(), non_neg_integer()}]
  def status_totals do
    Rule.read!(authorize?: false)
    |> Enum.group_by(& &1.status)
    |> Enum.map(fn {status, rules} -> {to_string(status), length(rules)} end)
  end

  @doc """
  Returns tag counts via raw SQL (unnesting the tags array column).
  Accepts an optional filters map with keys "status", "category", "severity".
  """
  @spec tag_cloud(map()) :: [{String.t(), non_neg_integer()}]
  def tag_cloud(filters \\ %{}) do
    {where_clause, params} = build_tag_query_filters(filters)

    case Ecto.Adapters.SQL.query(
           Maestro.Repo,
           "SELECT unnest(tags) as tag, count(*) as cnt FROM rules#{where_clause} GROUP BY tag ORDER BY cnt DESC",
           params
         ) do
      {:ok, %{rows: rows}} -> Enum.map(rows, fn [tag, cnt] -> {tag, cnt} end)
      _ -> []
    end
  end

  @doc "Exports bundles by running the mix task. Returns :ok or {:error, output}."
  @spec export_bundles() :: :ok | {:error, String.t()}
  def export_bundles do
    case System.cmd("mix", ["maestro.rules.export"], stderr_to_stdout: true) do
      {_output, 0} -> :ok
      {output, _} -> {:error, String.slice(output, 0, 200)}
    end
  end

  @doc "Extracts Cinder-compatible filter keys from URL params."
  @spec extract_cinder_filters(map()) :: map()
  def extract_cinder_filters(params) do
    params
    |> Enum.filter(fn {k, _v} -> k in ~w(status category severity) end)
    |> Map.new()
  end

  # ---------------------------------------------------------------------------
  # Dedup / Rule Web
  # ---------------------------------------------------------------------------

  @doc """
  Finds clusters of semantically similar rules using tag overlap + content word similarity.
  Returns a list of `%{canonical: rule, duplicates: [rules], similarity: float}` maps,
  sorted by cluster size descending.
  """
  @spec find_duplicate_clusters(keyword()) :: [map()]
  def find_duplicate_clusters(opts \\ []) do
    min_similarity = Keyword.get(opts, :min_similarity, 0.4)
    statuses = Keyword.get(opts, :statuses, [:approved, :proposed, :retired, :linter, :anti_pattern])

    rules =
      Rule.read!(authorize?: false)
      |> Enum.filter(&(&1.status in statuses))
      |> Enum.reject(&(not is_nil(&1.superseded_by_id)))

    # Build word sets for each rule
    indexed =
      Enum.map(rules, fn r ->
        words = content_words(r.content)
        tags = MapSet.new(r.tags || [])
        {r, words, tags}
      end)

    # Find pairs above similarity threshold
    pairs = find_similar_pairs(indexed, min_similarity)

    # Build clusters using union-find
    cluster_rules(pairs, rules)
  end

  @doc """
  Supersedes duplicate rules under a canonical rule.
  Takes a cluster map from `find_duplicate_clusters/1`.
  Returns the count of rules superseded.
  """
  @spec supersede_cluster(map()) :: non_neg_integer()
  def supersede_cluster(%{canonical: canonical, duplicates: dupes}) do
    Enum.count(dupes, fn dupe ->
      case Rule.supersede(dupe, %{superseded_by_id: canonical.id}, authorize?: false) do
        {:ok, _} -> true
        _ -> false
      end
    end)
  end

  @doc """
  Consolidates a cluster by creating a new "god rule" with synthesized content,
  then supersedes ALL rules in the cluster (including the old canonical) under it.

  The new rule inherits category, severity, and tags from the cluster.
  Returns `{:ok, god_rule, superseded_count}`.
  """
  @spec consolidate_cluster(String.t(), map(), keyword()) :: {:ok, map(), non_neg_integer()}
  def consolidate_cluster(content, cluster, opts \\ []) do
    category = Keyword.get(opts, :category, cluster.canonical.category)
    severity = Keyword.get(opts, :severity, cluster.canonical.severity || :should)

    # Merge tags from all rules in the cluster
    all_rules = [cluster.canonical | cluster.duplicates]
    merged_tags = all_rules |> Enum.flat_map(&(&1.tags || [])) |> Enum.uniq() |> Enum.sort()

    # Create the god rule
    {:ok, god_rule} =
      Rule.propose(%{
        content: content,
        category: category,
        severity: severity,
        tags: merged_tags,
        source_context: "consolidated:#{DateTime.to_iso8601(DateTime.utc_now())}",
        source_project_slug: "maestro"
      }, authorize?: false)

    # Approve it
    {:ok, god_rule} = Rule.approve(god_rule, authorize?: false)

    # Supersede all rules in the cluster under the god rule
    count = Enum.count(all_rules, fn rule ->
      if rule.status != :retired do
        case Rule.supersede(rule, %{superseded_by_id: god_rule.id}, authorize?: false) do
          {:ok, _} -> true
          _ -> false
        end
      else
        # Already retired — just link it
        Rule.update(rule, %{superseded_by_id: god_rule.id}, authorize?: false)
        true
      end
    end)

    {:ok, god_rule, count}
  end

  @doc """
  Returns the rule web: approved/proposed rules grouped by category with
  supersession relationships visible.
  """
  @spec rule_web() :: map()
  def rule_web do
    rules = Rule.read!(authorize?: false)

    by_status =
      rules
      |> Enum.group_by(& &1.status)
      |> Map.new(fn {status, rs} -> {status, length(rs)} end)

    clusters = find_duplicate_clusters(min_similarity: 0.35)

    %{
      totals: by_status,
      clusters: Enum.map(clusters, fn c ->
        %{
          canonical: %{id: c.canonical.id, content: String.slice(c.canonical.content, 0, 100), category: c.canonical.category, status: c.canonical.status},
          duplicates: Enum.map(c.duplicates, fn d ->
            %{id: d.id, content: String.slice(d.content, 0, 100), category: d.category, status: d.status, similarity: c.similarity}
          end),
          size: 1 + length(c.duplicates)
        }
      end),
      cluster_count: length(clusters),
      total_duplicates: Enum.sum(Enum.map(clusters, fn c -> length(c.duplicates) end))
    }
  end

  # -- Similarity helpers --

  defp content_words(nil), do: MapSet.new()

  defp content_words(content) do
    content
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s]/, " ")
    |> String.split(~r/\s+/, trim: true)
    |> Enum.reject(&(String.length(&1) < 3))
    |> Enum.reject(&(&1 in ~w(the and for not use always never with this that from are but has have)))
    |> MapSet.new()
  end

  defp jaccard(set_a, set_b) do
    intersection = MapSet.size(MapSet.intersection(set_a, set_b))
    union = MapSet.size(MapSet.union(set_a, set_b))
    if union == 0, do: 0.0, else: intersection / union
  end

  defp find_similar_pairs(indexed, min_similarity) do
    for {r1, w1, t1} <- indexed,
        {r2, w2, t2} <- indexed,
        r1.id < r2.id,
        r1.category == r2.category,
        sim = jaccard(w1, w2) * 0.7 + jaccard(t1, t2) * 0.3,
        sim >= min_similarity do
      {r1, r2, sim}
    end
  end

  defp cluster_rules(pairs, _rules) do
    # Union-find: group rules into clusters
    parent = Enum.reduce(pairs, %{}, fn {r1, r2, _sim}, acc ->
      root1 = find_root(acc, r1.id)
      root2 = find_root(acc, r2.id)
      if root1 != root2, do: Map.put(acc, root2, root1), else: acc
    end)

    # Collect clusters
    all_in_pairs =
      pairs
      |> Enum.flat_map(fn {r1, r2, _} -> [r1, r2] end)
      |> Enum.uniq_by(& &1.id)

    groups =
      Enum.filter(Enum.group_by(all_in_pairs, fn r -> find_root(parent, r.id) end), fn {_, members} ->
        length(members) > 1
      end)

    # For each cluster, pick canonical (approved > proposed, highest priority)
    Enum.sort_by(
      # For each cluster, pick canonical (approved > proposed, highest priority)
      Enum.map(groups, fn {_root, members} ->
        sorted =
          Enum.sort_by(members, fn r ->
            status_rank = if r.status == :approved, do: 0, else: 1
            {status_rank, -(r.priority || 0)}
          end)
    
        [canonical | dupes] = sorted
    
        avg_sim =
          if pairs != [] do
            relevant =
              Enum.filter(pairs, fn {r1, r2, _} ->
                r1.id in Enum.map(members, & &1.id) and r2.id in Enum.map(members, & &1.id)
              end)
    
            if relevant != [],
              do: Enum.sum(Enum.map(relevant, fn {_, _, s} -> s end)) / length(relevant),
              else: 0.0
          else
            0.0
          end
    
        %{canonical: canonical, duplicates: dupes, similarity: Float.round(avg_sim, 2)}
      end),
      fn c -> -(1 + length(c.duplicates)) end
    )
  end

  defp find_root(parent, id) do
    case Map.get(parent, id) do
      nil -> id
      ^id -> id
      parent_id -> find_root(parent, parent_id)
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp build_tag_query_filters(filters) when map_size(filters) == 0,
    do: {" WHERE status = 'proposed'", []}

  defp build_tag_query_filters(filters) do
    conditions = []
    params = []
    idx = 1

    {conditions, params, idx} =
      case Map.get(filters, "status") do
        nil -> {conditions, params, idx}
        status -> {conditions ++ ["status = $#{idx}"], params ++ [status], idx + 1}
      end

    {conditions, params, idx} =
      case Map.get(filters, "category") do
        nil -> {conditions, params, idx}
        category -> {conditions ++ ["category = $#{idx}"], params ++ [category], idx + 1}
      end

    {conditions, params, _idx} =
      case Map.get(filters, "severity") do
        nil -> {conditions, params, idx}
        severity -> {conditions ++ ["severity = $#{idx}"], params ++ [severity], idx + 1}
      end

    if conditions == [] do
      {"", []}
    else
      {" WHERE " <> Enum.join(conditions, " AND "), params}
    end
  end
end
