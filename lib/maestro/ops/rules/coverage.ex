defmodule Maestro.Ops.Rules.Coverage do
  @moduledoc """
  Pure query functions for rule coverage stats.
  Shared core used by both the LiveView UI and mix tasks.
  """

  alias Maestro.Ops.{Rule, Library, RuleSource, Skill}

  @doc """
  Returns coverage stats per library.
  Each entry: %{dep, version, source_count, file_count, approved, linter, retired, proposed, curated, coverage_pct}
  """
  def by_library do
    libraries = Library.read!()
    all_rules = Rule.read!()
    all_sources = RuleSource.read!()

    rules_by_lib = Enum.group_by(all_rules, & &1.source_project_slug)
    sources_by_lib = Enum.group_by(all_sources, & &1.library_id)
    linked_names = MapSet.new(libraries, & &1.name)

    lib_entries = Enum.map(libraries, &lib_stats(&1, rules_by_lib, sources_by_lib))

    orphan_entries =
      all_rules
      |> Enum.reject(&(is_nil(&1.source_project_slug) or MapSet.member?(linked_names, &1.source_project_slug)))
      |> Enum.group_by(& &1.source_project_slug)
      |> Enum.map(fn {slug, rules} -> orphan_stats(slug, rules) end)

    (lib_entries ++ orphan_entries)
    |> Enum.filter(&(&1.source_count > 0))
    |> Enum.sort_by(& &1.source_count, :desc)
  end

  @doc "Returns all skills."
  def skills, do: Skill.read!()

  @doc "Summary counts across all rules."
  def totals do
    all_rules = Rule.read!()

    %{
      all: length(all_rules),
      proposed: Enum.count(all_rules, &(&1.status == :proposed)),
      approved: Enum.count(all_rules, &(&1.status == :approved)),
      retired: Enum.count(all_rules, &(&1.status == :retired)),
      linter: Enum.count(all_rules, &(&1.status == :linter)),
      orphan: Enum.count(all_rules, &is_nil(&1.library_id))
    }
  end

  defp lib_stats(lib, rules_by_lib, sources_by_lib) do
    lib_rules = Map.get(rules_by_lib, lib.name, [])
    lib_sources = Map.get(sources_by_lib, lib.id, [])
    source_count = lib_sources |> Enum.map(& &1.rule_count) |> Enum.sum()

    count_stats(lib.name, lib.version, source_count, length(lib_sources), lib_rules)
  end

  defp orphan_stats(slug, rules) do
    count_stats(slug, nil, length(rules), 0, rules)
  end

  defp count_stats(dep, version, source_count, file_count, rules) do
    approved = Enum.count(rules, &(&1.status == :approved))
    linter = Enum.count(rules, &(&1.status == :linter))
    retired = Enum.count(rules, &(&1.status == :retired))
    proposed = Enum.count(rules, &(&1.status == :proposed))
    curated = approved + linter + retired
    pct = if source_count > 0, do: round(curated / source_count * 100), else: 0

    %{
      dep: dep,
      version: version,
      source_count: source_count,
      file_count: file_count,
      approved: approved,
      linter: linter,
      retired: retired,
      proposed: proposed,
      curated: curated,
      coverage_pct: pct
    }
  end
end
