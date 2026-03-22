defmodule Mix.Tasks.Maestro.Update do
  @moduledoc """
  Maestro's curation pipeline. Thin orchestrator shell.

  ## Usage

      mix maestro.update              # Full pipeline
      mix maestro.update --skip-deps  # Skip deps.update
      mix maestro.update --skip-sync  # Skip usage_rules.sync
      mix maestro.update --report     # Just report, no changes
  """

  use Mix.Task
  @shortdoc "Scan deps, sync rules, triage, report coverage"

  alias Maestro.Ops.{RuleParser, Rules.Triage, Rules.LintExtractor, Rules.SkillParser, Rules.Dedup, Rules.Coverage}

  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        strict: [skip_deps: :boolean, skip_sync: :boolean, report: :boolean]
      )

    unless opts[:skip_sync] || opts[:report] do
      phase("1: Deps + Sync", fn -> sync_upstream(opts) end)
    end

    libraries = phase("2: Libraries", &sync_libraries/0)

    unless opts[:report] do
      phase("3: Sources + Rules", fn -> sync_sources_and_rules(libraries) end)
      phase("3b: External Sources", &sync_external_sources/0)
    end

    phase("4: Skills", &sync_skills/0)
    phase("5: Coverage", &report_coverage/0)
  end

  defp phase(name, fun) do
    Mix.shell().info("\n━━━ #{name} ━━━")
    fun.()
  end

  # ── Phase 1 ─────────────────────────────────────────────────────────

  defp sync_upstream(opts) do
    unless opts[:skip_deps] do
      Mix.Task.run("deps.update", ["--all"])
    end

    # usage_rules.sync generates skills in .claude/skills/ from dep usage-rules files.
    # We removed `file: "AGENTS.md"` from the config so it no longer writes to AGENTS.md —
    # Maestro handles rule discovery and curation itself (Phase 2+3).
    try do
      Mix.Task.run("usage_rules.sync", ["--yes"])
      Mix.shell().info("  Skills sync complete")
    rescue
      e -> Mix.shell().info("  Skills sync failed: #{inspect(e)} — continuing")
    end
  end

  # ── Phase 2 ─────────────────────────────────────────────────────────

  defp sync_libraries do
    now = DateTime.utc_now()
    all_deps = Mix.Project.deps_paths()

    # Use the usage_rules config as the source of truth for which deps to track.
    # This keeps Maestro in sync with usage_rules conventions.
    configured_deps = resolve_configured_deps(all_deps)

    libraries =
      configured_deps
      |> Enum.map(fn {name, _path} ->
        dep = to_string(name)

        Maestro.Ops.Library.create(%{
          name: dep,
          version: RuleParser.get_dep_version(dep),
          description: RuleParser.get_dep_description(dep),
          last_synced_at: now
        })
      end)
      |> Enum.flat_map(fn
        {:ok, lib} -> [lib]
        {:error, _} -> []
      end)

    Mix.shell().info("  #{length(libraries)} libraries")
    libraries
  end

  # Resolve which deps to track from the usage_rules config in mix.exs.
  # Supports atoms, tuples, and regex patterns — same as usage_rules.sync.
  defp resolve_configured_deps(all_deps) do
    config = Mix.Project.config()[:usage_rules] || []
    usage_rules_specs = config[:usage_rules] || []
    skills_config = config[:skills] || []
    package_skills_specs = skills_config[:package_skills] || []

    # Collect all dep specs from both usage_rules and package_skills
    all_specs =
      Enum.map(usage_rules_specs, fn
        {spec, _opts} -> spec
        spec -> spec
      end) ++ package_skills_specs

    all_deps
    |> Enum.filter(fn {name, path} ->
      matches_any_spec?(name, all_specs) and
        (File.exists?(Path.join(path, "usage-rules.md")) or
           File.dir?(Path.join(path, "usage-rules")))
    end)
  end

  defp matches_any_spec?(dep_name, specs) do
    Enum.any?(specs, fn
      %Regex{} = re -> Regex.match?(re, to_string(dep_name))
      atom when is_atom(atom) -> dep_name == atom
      _ -> false
    end)
  end

  # ── Phase 3 ─────────────────────────────────────────────────────────

  defp sync_sources_and_rules(libraries) do
    existing_hashes = load_existing_hashes()
    existing_normalized = load_existing_normalized()
    now = DateTime.utc_now()

    stats =
      Enum.reduce(libraries, %{new: 0, exact: 0, near: 0, sources: 0}, fn lib, stats ->
        RuleParser.find_rule_files(lib.name)
        |> Enum.reduce(stats, fn path, stats ->
          sub = RuleParser.sub_rule_name(path)
          rules = RuleParser.parse_rules_from_file(path, lib.name, sub)

          {:ok, source} =
            Maestro.Ops.RuleSource.create(%{
              library_id: lib.id, file_path: path, sub_rule_name: sub,
              content_hash: RuleParser.file_hash(path),
              rule_count: length(rules), last_synced_at: now
            })

          stats = %{stats | sources: stats.sources + 1}

          Enum.reduce(rules, stats, fn rule, stats ->
            case Dedup.check(rule.content, rule.content_hash, existing_hashes, existing_normalized) do
              :exact_duplicate -> %{stats | exact: stats.exact + 1}
              :near_duplicate -> %{stats | near: stats.near + 1}
              :new ->
                ingest(rule, lib.id, source.id)
                %{stats | new: stats.new + 1}
            end
          end)
        end)
      end)

    link_orphan_rules()
    triage_proposed()
    backfill_lint_metadata()

    Mix.shell().info(
      "  #{stats.sources} sources, #{stats.new} new, #{stats.exact} exact dupes, #{stats.near} near dupes"
    )
  end

  defp ingest(rule_attrs, library_id, source_id) do
    decision = Triage.decide(rule_attrs.content, rule_attrs.source_project_slug)

    attrs = Map.merge(rule_attrs, %{library_id: library_id, rule_source_id: source_id})

    case Maestro.Ops.Rule.create(attrs) do
      {:ok, rule} -> apply_decision(rule, decision)
      {:error, _} -> :error
    end
  end

  defp apply_decision(rule, %{status: :approved}), do: Maestro.Ops.Rule.approve(rule)
  defp apply_decision(rule, %{status: :linter} = d), do: Maestro.Ops.Rule.mark_linter(rule, Map.get(d, :lint, %{}))
  defp apply_decision(rule, %{status: :retired, reason: r}), do: Maestro.Ops.Rule.retire(rule, %{retired_reason: r})

  # ── Phase 3b: External sources (AGENTS.md files from generated projects) ──

  @external_sources [
    %{
      name: "phoenix-framework",
      description: "Phoenix v1.8 AGENTS.md — generated by phx.new",
      paths: [
        "/Users/vince/dev/ash_26_02/AGENTS.md"
      ]
    }
  ]

  defp sync_external_sources do
    existing_hashes = load_existing_hashes()
    existing_normalized = load_existing_normalized()
    now = DateTime.utc_now()

    for source_config <- @external_sources do
      # Upsert library for external source
      {:ok, lib} =
        Maestro.Ops.Library.create(%{
          name: source_config.name,
          description: source_config.description,
          version: RuleParser.get_dep_version("phoenix"),
          last_synced_at: now
        })

      for path <- source_config.paths, File.exists?(path) do
        rules = RuleParser.parse_agents_file(path, source_config.name)

        {:ok, rs} =
          Maestro.Ops.RuleSource.create(%{
            library_id: lib.id,
            file_path: path,
            sub_rule_name: "agents",
            content_hash: RuleParser.file_hash(path),
            rule_count: length(rules),
            last_synced_at: now
          })

        {new, exact, near} =
          Enum.reduce(rules, {0, 0, 0}, fn rule, {n, e, nr} ->
            case Dedup.check(rule.content, rule.content_hash, existing_hashes, existing_normalized) do
              :exact_duplicate -> {n, e + 1, nr}
              :near_duplicate -> {n, e, nr + 1}
              :new ->
                ingest(rule, lib.id, rs.id)
                {n + 1, e, nr}
            end
          end)

        Mix.shell().info("  #{source_config.name}: #{new} new, #{exact} exact dupes, #{near} near dupes")
      end
    end
  end

  defp link_orphan_rules do
    %{num_rows: n} =
      Maestro.Repo.query!("""
      UPDATE rules r SET library_id = l.id
      FROM libraries l
      WHERE r.source_project_slug = l.name AND r.library_id IS NULL
      """)

    if n > 0, do: Mix.shell().info("  Linked #{n} legacy rules")
  end

  defp triage_proposed do
    Maestro.Ops.Rule.read!()
    |> Enum.filter(&(&1.status == :proposed))
    |> Enum.each(fn rule ->
      apply_decision(rule, Triage.decide(rule.content, rule.source_project_slug))
    end)
  end

  defp backfill_lint_metadata do
    Maestro.Ops.Rule.read!()
    |> Enum.filter(&(&1.status == :linter and is_nil(&1.lint_pattern)))
    |> Enum.each(fn rule ->
      case LintExtractor.extract(rule.content) do
        nil -> :skip
        config -> Maestro.Ops.Rule.mark_linter(rule, config)
      end
    end)
  end

  defp load_existing_hashes do
    Maestro.Ops.Rule.read!()
    |> Enum.map(& &1.content_hash)
    |> Enum.reject(&is_nil/1)
    |> MapSet.new()
  end

  defp load_existing_normalized do
    Maestro.Ops.Rule.read!()
    |> Enum.map(&RuleParser.normalize(&1.content))
  end

  # ── Phase 4 ─────────────────────────────────────────────────────────

  defp sync_skills do
    now = DateTime.utc_now()

    skills =
      SkillParser.discover()
      |> Enum.flat_map(fn attrs ->
        case Maestro.Ops.Skill.create(Map.put(attrs, :last_synced_at, now)) do
          {:ok, skill} -> [skill]
          {:error, _} -> []
        end
      end)

    Mix.shell().info("  #{length(skills)} skills")
  end

  # ── Phase 5 ─────────────────────────────────────────────────────────

  defp report_coverage do
    for d <- Coverage.by_library() do
      Mix.shell().info(
        "  #{String.pad_trailing(d.dep, 22)} #{d.version || "?"}" <>
          "  src:#{String.pad_leading("#{d.source_count}", 4)}" <>
          "  #{String.pad_leading("#{d.coverage_pct}", 3)}%" <>
          "  a:#{d.approved} l:#{d.linter} r:#{d.retired}" <>
          "  files:#{d.file_count}"
      )
    end

    totals = Coverage.totals()
    if totals.orphan > 0, do: Mix.shell().info("\n  #{totals.orphan} unlinked rules")

    skills = Coverage.skills()
    Mix.shell().info("\n  #{length(skills)} skills:")
    for s <- Enum.sort_by(skills, & &1.name) do
      Mix.shell().info("    #{s.name} — #{Enum.join(s.library_names, ", ")}")
    end
  end
end
