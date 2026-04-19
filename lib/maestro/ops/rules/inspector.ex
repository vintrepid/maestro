defmodule Maestro.Ops.Rules.Inspector do
  @moduledoc """
  Read-only introspection of the rules DB. Surfaces the shape of the
  curated corpus so pipeline quality can be assessed:

  - Per-library status breakdown (approved / proposed / retired / linter).
  - Retired-reason buckets — the Triage module's "why it was dropped."
  - Linter metadata health — dangling `lint_pattern`, missing `fix_type`.
  - Rule-level drill-in.

  All functions return plain maps/lists. Formatting lives in the mix task.
  """

  import Ecto.Query
  alias Maestro.Repo

  @doc "Rows for the default library × status table."
  @spec per_library_status() :: [map()]
  def per_library_status do
    rows =
      Repo.all(
        from r in "rules",
          left_join: l in "libraries",
          on: l.id == r.library_id,
          group_by: [l.name, r.status],
          select: %{library: l.name, status: r.status, count: count(r.id)}
      )

    rows
    |> Enum.group_by(& &1.library)
    |> Enum.map(fn {lib, group} ->
      counts = Map.new(group, fn %{status: s, count: c} -> {s, c} end)

      %{
        library: lib || "(none)",
        total: Enum.sum(Map.values(counts)),
        approved: Map.get(counts, "approved", 0),
        proposed: Map.get(counts, "proposed", 0),
        retired: Map.get(counts, "retired", 0),
        linter: Map.get(counts, "linter", 0),
        anti_pattern: Map.get(counts, "anti_pattern", 0)
      }
    end)
    |> Enum.sort_by(& &1.total, :desc)
  end

  @doc "Retired-reason buckets for one library (or all)."
  @spec retired_reason_buckets(String.t() | nil) :: [map()]
  def retired_reason_buckets(library \\ nil) do
    base_query =
      from r in "rules",
        left_join: l in "libraries",
        on: l.id == r.library_id,
        where: r.status == "retired",
        group_by: r.retired_reason,
        select: %{reason: r.retired_reason, count: count(r.id)}

    query =
      case library do
        nil -> base_query
        name -> from [r, l] in base_query, where: l.name == ^name
      end

    query
    |> Repo.all()
    |> Enum.sort_by(& &1.count, :desc)
  end

  @doc "Sample N rules per retired-reason bucket for one library."
  @spec sample_retired(String.t(), integer()) :: %{(String.t() | nil) => [map()]}
  def sample_retired(library, n \\ 5) do
    rows =
      Repo.all(
        from r in "rules",
          join: l in "libraries",
          on: l.id == r.library_id,
          where: r.status == "retired" and l.name == ^library,
          select: %{
            id: type(r.id, :string),
            content: r.content,
            retired_reason: r.retired_reason
          }
      )

    rows
    |> Enum.group_by(& &1.retired_reason)
    |> Map.new(fn {reason, rs} -> {reason, Enum.take(rs, n)} end)
  end

  @doc "All rules in a given (library, retired_reason) bucket."
  @spec drill_bucket(String.t(), String.t() | nil) :: [map()]
  def drill_bucket(library, reason) do
    base =
      from r in "rules",
        join: l in "libraries",
        on: l.id == r.library_id,
        where: r.status == "retired" and l.name == ^library,
        select: %{
          id: type(r.id, :string),
          content: r.content,
          retired_reason: r.retired_reason,
          source_commit: r.source_commit
        }

    query =
      case reason do
        nil -> from [r, _l] in base, where: is_nil(r.retired_reason)
        r -> from [r_, _l] in base, where: r_.retired_reason == ^r
      end

    Repo.all(query)
  end

  @doc "Linter health — how many rules carry metadata vs how many are actual `:linter` status."
  @spec linter_health() :: map()
  def linter_health do
    rows =
      Repo.all(
        from r in "rules",
          select: %{
            status: r.status,
            has_lint_pattern: not is_nil(r.lint_pattern),
            has_lint_config: not is_nil(r.lint_config),
            has_fix_type: not is_nil(r.fix_type)
          }
      )

    %{
      total: length(rows),
      linter_status: Enum.count(rows, &(&1.status == "linter")),
      with_lint_pattern: Enum.count(rows, & &1.has_lint_pattern),
      with_lint_config: Enum.count(rows, & &1.has_lint_config),
      with_fix_type: Enum.count(rows, & &1.has_fix_type),
      dangling_lint_metadata:
        Enum.count(rows, fn r ->
          (r.has_lint_pattern or r.has_lint_config) and r.status != "linter"
        end)
    }
  end

  @doc """
  IDs of retired rules, optionally scoped to one library. Pure selector
  — feed the result into `Maestro.Ops.Rules.Action.diagnose/1` to re-score
  each rule through Triage.
  """
  @spec retired_ids(String.t() | nil) :: [String.t()]
  def retired_ids(library \\ nil) do
    base =
      from r in "rules",
        left_join: l in "libraries",
        on: l.id == r.library_id,
        where: r.status == "retired",
        select: type(r.id, :string)

    query =
      case library do
        nil -> base
        name -> from [_r, l] in base, where: l.name == ^name
      end

    Repo.all(query)
  end

  @doc "IDs of rules with lint_* metadata set but status != :linter."
  @spec dangling_linter_ids() :: [String.t()]
  def dangling_linter_ids do
    Repo.all(
      from r in "rules",
        where:
          (not is_nil(r.lint_pattern) or not is_nil(r.lint_config)) and
            r.status != "linter",
        select: type(r.id, :string)
    )
  end

  @doc "Full rule record for drill-in by id."
  @spec drill_rule(String.t()) :: map() | nil
  def drill_rule(id) do
    Repo.one(
      from r in "rules",
        left_join: l in "libraries",
        on: l.id == r.library_id,
        where: r.id == type(^id, :binary_id),
        select: %{
          id: type(r.id, :string),
          library: l.name,
          status: r.status,
          severity: r.severity,
          category: r.category,
          content: r.content,
          retired_reason: r.retired_reason,
          source_commit: r.source_commit,
          source_project_slug: r.source_project_slug,
          superseded_by_id: type(r.superseded_by_id, :string),
          lint_pattern: r.lint_pattern,
          fix_type: r.fix_type,
          inserted_at: r.inserted_at,
          retired_at: r.retired_at
        }
    )
  end
end
