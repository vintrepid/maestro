defmodule Maestro.Ops.Rules.Curator do
  @moduledoc """
  Rules curation pipeline — the domain logic for discovering, ingesting,
  triaging, quality-gating, and packaging rules.

  Seven phases:
  1. **Sync upstream** — update deps, sync usage_rules skills
  2. **Libraries** — upsert Library records from configured deps
  3. **Sources + Rules** — parse rule files, dedup, ingest new rules, triage
  4. **External sources** — discover .md/.json in project root and extra dirs
  5. **Skills** — discover and sync skill definitions
  6. **Quality gate** — audit approved rules, demote failures, auto-fix proposed
  7. **Write outputs** — generate RULES.md, rules.json
  8. **Coverage** — report per-library stats

  The mix task `mix maestro.rules.curate` is a thin shell that calls `run/1`.
  """

  alias Maestro.Ops.{Rule, Library, RuleSource, RuleParser, Skill}
  alias Maestro.Ops.Rules.{Triage, LintExtractor, SkillParser, Dedup, Coverage, Quality}

  @curate_outputs ~w(RULES.md rules.json)
  @extra_scan_dirs [
    {"/Users/vince/.claude/projects/-Users-vince-dev-maestro/memory", "claude-memory"},
    {"agents/docs", "agents"}
  ]

  @doc """
  Run the full curation pipeline. Options:
  - `:skip_deps` — skip deps.update
  - `:skip_sync` — skip usage_rules.sync and external sources
  - `:report` — read-only, no mutations
  """
  @spec run(keyword()) :: :ok
  def run(opts \\ []) do
    unless opts[:skip_sync] || opts[:report] do
      log("1: Deps + Sync")
      sync_upstream(opts)
    end

    log("2: Libraries")
    libraries = sync_libraries()

    unless opts[:report] do
      log("3: Sources + Rules")
      sync_sources_and_rules(libraries)

      log("3b: External Sources")
      sync_external_sources()
    end

    log("4: Skills")
    sync_skills()

    log("5: Quality Gate")
    quality_gate()

    log("6: Write Outputs")
    write_outputs()

    log("7: Coverage")
    report_coverage()

    :ok
  end

  # ── Phase 1 ─────────────────────────────────────────────────────────

  defp sync_upstream(opts) do
    unless opts[:skip_deps] do
      Mix.Task.run("deps.update", ["--all"])
    end

    try do
      Mix.Task.run("usage_rules.sync", ["--yes"])
      log("  Skills sync complete")
    rescue
      e -> log("  Skills sync failed: #{inspect(e)} — continuing")
    end
  end

  # ── Phase 2 ─────────────────────────────────────────────────────────

  defp sync_libraries do
    now = DateTime.utc_now()
    all_deps = Mix.Project.deps_paths()
    configured_deps = resolve_configured_deps(all_deps)

    libraries =
      configured_deps
      |> Enum.map(fn {name, _path} ->
        dep = to_string(name)

        Library.create(%{
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

    log("  #{length(libraries)} libraries")
    libraries
  end

  defp resolve_configured_deps(all_deps) do
    config = Mix.Project.config()[:usage_rules] || []
    usage_rules_specs = config[:usage_rules] || []
    skills_config = config[:skills] || []
    package_skills_specs = skills_config[:package_skills] || []

    all_specs =
      Enum.map(usage_rules_specs, fn
        {spec, _opts} -> spec
        spec -> spec
      end) ++ package_skills_specs

    Enum.filter(all_deps, fn {name, path} ->
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
    rehash_and_dedup()
    existing_hashes = load_existing_hashes()
    existing_normalized = load_existing_normalized()
    now = DateTime.utc_now()

    stats =
      Enum.reduce(libraries, %{new: 0, exact: 0, near: 0, sources: 0}, fn lib, stats ->
        Enum.reduce(RuleParser.find_rule_files(lib.name), stats, fn path, stats ->
          sub = RuleParser.sub_rule_name(path)
          rules = RuleParser.parse_rules_from_file(path, lib.name, sub)

          {:ok, source} =
            RuleSource.create(%{
              library_id: lib.id,
              file_path: path,
              sub_rule_name: sub,
              content_hash: RuleParser.file_hash(path),
              rule_count: length(rules),
              last_synced_at: now
            })

          stats = %{stats | sources: stats.sources + 1}

          Enum.reduce(rules, stats, fn rule, stats ->
            case Dedup.check(
                   rule.content,
                   rule.content_hash,
                   existing_hashes,
                   existing_normalized
                 ) do
              :exact_duplicate ->
                %{stats | exact: stats.exact + 1}

              :near_duplicate ->
                %{stats | near: stats.near + 1}

              :new ->
                ingest(rule, lib.id, source.id)
                %{stats | new: stats.new + 1}
            end
          end)
        end)
      end)

    link_orphan_rules()
    triage_proposed()
    retriage_approved()
    backfill_lint_metadata()

    log(
      "  #{stats.sources} sources, #{stats.new} new, #{stats.exact} exact dupes, #{stats.near} near dupes"
    )
  end

  defp ingest(rule_attrs, library_id, source_id) do
    decision = Triage.decide(rule_attrs.content, rule_attrs.source_project_slug)
    attrs = Map.merge(rule_attrs, %{library_id: library_id, rule_source_id: source_id})

    case Rule.create(attrs) do
      {:ok, rule} -> apply_decision(rule, decision)
      {:error, _} -> :error
    end
  end

  defp apply_decision(rule, %{status: :approved}), do: Rule.approve(rule)

  defp apply_decision(rule, %{status: :linter} = d),
    do: Rule.mark_linter(rule, Map.get(d, :lint, %{}))

  defp apply_decision(rule, %{status: :retired, reason: r}),
    do: Rule.retire(rule, %{retired_reason: r})

  defp apply_decision(_rule, %{status: :proposed}), do: :ok

  # ── Phase 3b: External sources ──

  defp sync_external_sources do
    existing_hashes = load_existing_hashes()
    existing_normalized = load_existing_normalized()
    now = DateTime.utc_now()
    root = File.cwd!()

    root_files =
      (Path.wildcard(Path.join(root, "*.md")) ++ Path.wildcard(Path.join(root, "*.json")))
      |> Enum.reject(fn path -> Path.basename(path) in @curate_outputs end)
      |> Enum.filter(&File.regular?/1)

    file_sources =
      Enum.map(root_files, fn path ->
        %{path: path, name: "maestro-project", parser: detect_parser(path)}
      end)

    dir_sources =
      Enum.flat_map(@extra_scan_dirs, fn {dir, name} ->
        dir = if Path.type(dir) == :relative, do: Path.join(root, dir), else: dir

        if File.dir?(dir) do
          (Path.wildcard(Path.join(dir, "**/*.md")) ++ Path.wildcard(Path.join(dir, "**/*.json")))
          |> Enum.filter(&File.regular?/1)
          |> Enum.map(fn path -> %{path: path, name: name, parser: detect_parser(path)} end)
        else
          []
        end
      end)

    (file_sources ++ dir_sources)
    |> Enum.group_by(& &1.name)
    |> Enum.each(fn {lib_name, sources} ->
      {:ok, lib} =
        Library.create(%{
          name: lib_name,
          description: "Auto-discovered from project root",
          version: nil,
          last_synced_at: now
        })

      {total_new, total_exact, total_near} =
        Enum.reduce(sources, {0, 0, 0}, fn source, {tn, te, tnr} ->
          rules = parse_external(source.parser, source.path, lib_name)
          hash = RuleParser.file_hash(source.path)

          {:ok, rs} =
            RuleSource.create(%{
              library_id: lib.id,
              file_path: source.path,
              sub_rule_name: Path.basename(source.path, Path.extname(source.path)),
              content_hash: hash,
              rule_count: length(rules),
              last_synced_at: now
            })

          Enum.reduce(rules, {tn, te, tnr}, fn rule, {n, e, nr} ->
            case Dedup.check(
                   rule.content,
                   rule.content_hash,
                   existing_hashes,
                   existing_normalized
                 ) do
              :exact_duplicate ->
                {n, e + 1, nr}

              :near_duplicate ->
                {n, e, nr + 1}

              :new ->
                ingest(rule, lib.id, rs.id)
                {n + 1, e, nr}
            end
          end)
        end)

      log(
        "  #{lib_name}: #{total_new} new, #{total_exact} exact, #{total_near} near (#{length(sources)} files)"
      )
    end)
  end

  defp detect_parser(path) do
    if Path.extname(path) == ".json", do: :startup_json, else: :agents
  end

  defp parse_external(:agents, path, name), do: RuleParser.parse_agents_file(path, name)
  defp parse_external(:startup_json, path, name), do: RuleParser.parse_startup_json(path, name)
  defp parse_external(:memory_dir, path, name), do: RuleParser.parse_memory_dir(path, name)

  defp link_orphan_rules do
    orphans =
      Enum.filter(Rule.read!(), &(is_nil(&1.library_id) and not is_nil(&1.source_project_slug)))

    libraries_by_name =
      Map.new(Library.read!(), &{&1.name, &1.id})

    linked =
      Enum.reduce(orphans, 0, fn rule, count ->
        case Map.get(libraries_by_name, rule.source_project_slug) do
          nil ->
            count

          lib_id ->
            Rule.update(rule, %{library_id: lib_id})
            count + 1
        end
      end)

    if linked > 0, do: log("  Linked #{linked} legacy rules")
  end

  defp triage_proposed do
    Rule.read!()
    |> Enum.filter(&(&1.status == :proposed))
    |> Enum.each(fn rule ->
      apply_decision(rule, Triage.decide(rule.content, rule.source_project_slug))
    end)
  end

  defp retriage_approved do
    demoted =
      Enum.reduce(Rule.approved!(), 0, fn rule, count ->
        case Triage.decide(rule.content, rule.source_project_slug) do
          %{status: :retired, reason: reason} ->
            Rule.retire(rule, %{retired_reason: reason})
            count + 1

          _ ->
            count
        end
      end)

    if demoted > 0, do: log("  #{demoted} approved rules retired by updated triage")
  end

  defp backfill_lint_metadata do
    Rule.read!()
    |> Enum.filter(&(&1.status == :linter and is_nil(&1.lint_pattern)))
    |> Enum.each(fn rule ->
      case LintExtractor.extract(rule.content) do
        nil -> :skip
        config -> Rule.mark_linter(rule, config)
      end
    end)
  end

  defp rehash_and_dedup do
    all_rules = Rule.read!()

    rehashed =
      Enum.reduce(all_rules, 0, fn rule, count ->
        new_hash = RuleParser.content_hash(rule.content)

        if new_hash != rule.content_hash do
          Rule.update(rule, %{content_hash: new_hash})
          count + 1
        else
          count
        end
      end)

    if rehashed > 0, do: log("  #{rehashed} rules rehashed")

    all_rules = Rule.read!()

    duplicates =
      all_rules
      |> Enum.group_by(& &1.content_hash)
      |> Enum.filter(fn {_hash, rules} -> length(rules) > 1 end)

    purged =
      Enum.reduce(duplicates, 0, fn {_hash, rules}, count ->
        keep =
          rules
          |> Enum.sort_by(fn r ->
            priority = %{approved: 0, linter: 1, proposed: 2, retired: 3}
            {Map.get(priority, r.status, 4), r.inserted_at}
          end)
          |> hd()

        all_notes =
          rules
          |> Enum.map(& &1.notes)
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq()
          |> Enum.join("; ")

        if all_notes != "" and (is_nil(keep.notes) or keep.notes == "") do
          Rule.update(keep, %{notes: all_notes})
        end

        dupes = Enum.reject(rules, &(&1.id == keep.id))
        Enum.each(dupes, &Rule.destroy/1)
        count + length(dupes)
      end)

    if purged > 0, do: log("  #{purged} duplicate rules purged")
  end

  defp load_existing_hashes do
    Rule.read!()
    |> Enum.map(& &1.content_hash)
    |> Enum.reject(&is_nil/1)
    |> MapSet.new()
  end

  defp load_existing_normalized do
    Enum.map(Rule.read!(), &RuleParser.normalize(&1.content))
  end

  # ── Phase 4 ─────────────────────────────────────────────────────────

  defp sync_skills do
    now = DateTime.utc_now()

    skills =
      Enum.flat_map(SkillParser.discover(), fn attrs ->
        case Skill.create(Map.put(attrs, :last_synced_at, now)) do
          {:ok, skill} -> [skill]
          {:error, _} -> []
        end
      end)

    log("  #{length(skills)} skills")
  end

  # ── Phase 5: Quality gate ──────────────────────────────────────────

  defp quality_gate do
    approved = Rule.approved!()
    approved_results = Quality.audit_rules(approved)

    failing = Enum.reject(approved_results, & &1.pass?)
    passing = Enum.filter(approved_results, & &1.pass?)

    demoted =
      failing
      |> Enum.map(fn result ->
        rule = Rule.by_id!(result.id)
        Rule.reset_to_proposed(rule)
        result
      end)
      |> length()

    log("  #{length(passing)} approved (pass quality)")

    if demoted > 0 do
      log("  #{demoted} demoted to proposed (failed quality)")
      summary = Quality.summarize(approved_results)
      for ic <- summary.issues_by_check, do: log("    #{ic.check}: #{ic.count}")
    end

    proposed = Enum.filter(Rule.read!(), &(&1.status == :proposed))
    proposed_results = Quality.audit_rules(proposed)
    proposed_failing = Enum.reject(proposed_results, & &1.pass?)

    already_passing =
      proposed_results
      |> Enum.filter(& &1.pass?)
      |> Enum.each(fn result ->
        rule = Rule.by_id!(result.id)
        Rule.approve(rule)
      end)
      |> then(fn _ -> Enum.count(proposed_results, & &1.pass?) end)

    if already_passing > 0,
      do: log("  #{already_passing} proposed rules passed quality — approved")

    {auto_fixed, unfixable} =
      Enum.reduce(proposed_failing, {0, 0}, fn result, {fixed, skipped} ->
        rule = Rule.by_id!(result.id)

        case Quality.fix_content(rule.content, rule) do
          {:ok, new_content} ->
            new_hash = RuleParser.content_hash(new_content)
            {:ok, updated} = Rule.update(rule, %{content: new_content, content_hash: new_hash})
            Rule.approve(updated)
            {fixed + 1, skipped}

          :skip ->
            {fixed, skipped + 1}
        end
      end)

    if auto_fixed > 0, do: log("  #{auto_fixed} proposed rules auto-fixed and approved")
    if unfixable > 0, do: log("  #{unfixable} proposed rules need manual quality fixes")
  end

  # ── Phase 6: Write outputs ─────────────────────────────────────────

  defp write_outputs do
    rules = Rule.approved!()
    write_rules_md(rules)
    write_rules_json(rules)
  end

  defp write_rules_md(rules) do
    by_category = Enum.sort_by(Enum.group_by(rules, & &1.category), &elem(&1, 0))

    content =
      [
        "# Rules",
        "# Curated by Maestro · #{Date.utc_today()} · #{length(rules)} approved rules",
        ""
      ] ++
        Enum.flat_map(by_category, fn {category, cat_rules} ->
          always = Enum.filter(cat_rules, &(&1.severity == :must))
          should = Enum.filter(cat_rules, &(&1.severity != :must))
          header = ["## #{category |> to_string() |> String.capitalize()}", ""]
          always_lines = Enum.map(always, fn r -> "**ALWAYS** #{r.content}" end)
          should_lines = Enum.map(should, fn r -> "- #{r.content}" end)
          header ++ always_lines ++ should_lines ++ [""]
        end)

    File.write!("RULES.md", Enum.join(content, "\n"))
    log("  RULES.md (#{length(rules)} rules)")
  end

  defp write_rules_json(rules) do
    json_rules =
      Enum.map(rules, fn r ->
        base = %{id: r.id, content: r.content, category: r.category, severity: r.severity}

        if r.fix_type do
          Map.merge(base, %{
            fix_type: r.fix_type,
            fix_template: r.fix_template,
            fix_target: r.fix_target,
            fix_search: r.fix_search
          })
        else
          base
        end
      end)

    File.write!("rules.json", Jason.encode!(json_rules, pretty: true))
    log("  rules.json (#{length(rules)} rules)")
  end

  # ── Phase 7: Coverage ──────────────────────────────────────────────

  defp report_coverage do
    for d <- Coverage.by_library() do
      log(
        "  #{String.pad_trailing(d.dep, 22)} #{d.version || "?"}" <>
          "  src:#{String.pad_leading("#{d.source_count}", 4)}" <>
          "  #{String.pad_leading("#{d.coverage_pct}", 3)}%" <>
          "  a:#{d.approved} l:#{d.linter} r:#{d.retired}" <>
          "  files:#{d.file_count}"
      )
    end

    totals = Coverage.totals()
    if totals.orphan > 0, do: log("\n  #{totals.orphan} unlinked rules")

    skills = Coverage.skills()
    log("\n  #{length(skills)} skills:")

    for s <- Enum.sort_by(skills, & &1.name),
        do: log("    #{s.name} — #{Enum.join(s.library_names, ", ")}")
  end

  # ── Helpers ────────────────────────────────────────────────────────

  defp log(msg), do: Mix.shell().info(msg)
end
