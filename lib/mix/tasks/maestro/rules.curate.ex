defmodule Mix.Tasks.Maestro.Rules.Curate do
  @moduledoc """
  Maestro's rules curation pipeline. Thin orchestrator shell.

  ## Usage

      mix maestro.rules.curate              # Full pipeline
      mix maestro.rules.curate --skip-deps  # Skip deps.update
      mix maestro.rules.curate --skip-sync  # Skip usage_rules.sync
      mix maestro.rules.curate --report     # Just report, no changes
  """

  use Mix.Task
  @shortdoc "Scan deps, sync rules, triage, quality gate, write outputs"

  alias Maestro.Ops.{RuleParser, Rules.Triage, Rules.LintExtractor, Rules.SkillParser, Rules.Dedup, Rules.Coverage, Rules.Quality}

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
    phase("5: Quality Gate", &quality_gate/0)
    phase("6: Write Outputs", &write_outputs/0)
    phase("7: Coverage", &report_coverage/0)
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
    rehash_and_dedup()
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
    retriage_approved()
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
  defp apply_decision(_rule, %{status: :proposed}), do: :ok

  # ── Phase 3b: External sources ──
  # Data-driven: discovers .md and .json files in project root + known dirs.
  # No hardcoded file lists — parser is chosen by file extension and content.

  # Files that curate should never ingest (they're outputs, not sources)
  @curate_outputs ~w(RULES.md rules.json)
  # Dirs to also scan (e.g. memory files)
  @extra_scan_dirs [
    {"/Users/vince/.claude/projects/-Users-vince-dev-maestro/memory", "claude-memory"},
    {"agents/docs", "agents"}
  ]

  defp sync_external_sources do
    existing_hashes = load_existing_hashes()
    existing_normalized = load_existing_normalized()
    now = DateTime.utc_now()

    # Discover root .md and .json files
    root = File.cwd!()
    root_files =
      (Path.wildcard(Path.join(root, "*.md")) ++ Path.wildcard(Path.join(root, "*.json")))
      |> Enum.reject(fn path -> Path.basename(path) in @curate_outputs end)
      |> Enum.filter(&File.regular?/1)

    # Group into sources by library name
    file_sources = Enum.map(root_files, fn path ->
      %{path: path, name: "maestro-project", parser: detect_parser(path)}
    end)

    # Add extra scan dirs — expand into individual file sources
    dir_sources = Enum.flat_map(@extra_scan_dirs, fn {dir, name} ->
      dir = if Path.type(dir) == :relative, do: Path.join(root, dir), else: dir

      if File.dir?(dir) do
        # Recursively discover .md and .json files
        (Path.wildcard(Path.join(dir, "**/*.md")) ++ Path.wildcard(Path.join(dir, "**/*.json")))
        |> Enum.filter(&File.regular?/1)
        |> Enum.map(fn path -> %{path: path, name: name, parser: detect_parser(path)} end)
      else
        []
      end
    end)

    all_sources = file_sources ++ dir_sources

    # Group by library name and process
    all_sources
    |> Enum.group_by(& &1.name)
    |> Enum.each(fn {lib_name, sources} ->
      {:ok, lib} =
        Maestro.Ops.Library.create(%{
          name: lib_name,
          description: "Auto-discovered from project root",
          version: nil,
          last_synced_at: now
        })

      {total_new, total_exact, total_near} =
        Enum.reduce(sources, {0, 0, 0}, fn source, {tn, te, tnr} ->
          rules = parse_external(source.parser, source.path, lib_name)

          hash =
            if File.dir?(source.path) do
              files = Path.wildcard(Path.join(source.path, "*.md")) |> Enum.join(",")
              :crypto.hash(:sha256, files) |> Base.encode16(case: :lower)
            else
              RuleParser.file_hash(source.path)
            end

          {:ok, rs} =
            Maestro.Ops.RuleSource.create(%{
              library_id: lib.id,
              file_path: source.path,
              sub_rule_name: Path.basename(source.path, Path.extname(source.path)),
              content_hash: hash,
              rule_count: length(rules),
              last_synced_at: now
            })

          Enum.reduce(rules, {tn, te, tnr}, fn rule, {n, e, nr} ->
            case Dedup.check(rule.content, rule.content_hash, existing_hashes, existing_normalized) do
              :exact_duplicate -> {n, e + 1, nr}
              :near_duplicate -> {n, e, nr + 1}
              :new ->
                ingest(rule, lib.id, rs.id)
                {n + 1, e, nr}
            end
          end)
        end)

      Mix.shell().info("  #{lib_name}: #{total_new} new, #{total_exact} exact, #{total_near} near (#{length(sources)} files)")
    end)
  end

  defp detect_parser(path) do
    ext = Path.extname(path)
    basename = Path.basename(path)

    cond do
      ext == ".json" and String.contains?(basename, "startup") -> :startup_json
      ext == ".json" and String.contains?(basename, "task") -> :startup_json
      ext == ".json" -> :startup_json
      basename == "AGENTS.md" -> :agents
      ext == ".md" -> :agents
      true -> :agents
    end
  end

  defp parse_external(:agents, path, name), do: RuleParser.parse_agents_file(path, name)
  defp parse_external(:startup_json, path, name), do: RuleParser.parse_startup_json(path, name)
  defp parse_external(:memory_dir, path, name), do: RuleParser.parse_memory_dir(path, name)

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

  # Re-triage approved rules against updated triage logic.
  # If triage now says :retired, demote. Keeps old approvals honest.
  defp retriage_approved do
    demoted =
      Maestro.Ops.Rule.approved!()
      |> Enum.reduce(0, fn rule, count ->
        case Triage.decide(rule.content, rule.source_project_slug) do
          %{status: :retired, reason: reason} ->
            Maestro.Ops.Rule.retire(rule, %{retired_reason: reason})
            count + 1

          _ ->
            count
        end
      end)

    if demoted > 0, do: Mix.shell().info("  #{demoted} approved rules retired by updated triage")
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

  # Rehash all rules with current normalize logic, then purge duplicates.
  # Keeps the "best" rule per normalized hash: approved > linter > proposed > retired, oldest wins ties.
  defp rehash_and_dedup do
    all_rules = Maestro.Ops.Rule.read!()

    # Rehash any rules whose stored hash doesn't match current normalization
    rehashed =
      Enum.reduce(all_rules, 0, fn rule, count ->
        new_hash = RuleParser.content_hash(rule.content)

        if new_hash != rule.content_hash do
          Maestro.Ops.Rule.update(rule, %{content_hash: new_hash})
          count + 1
        else
          count
        end
      end)

    if rehashed > 0, do: Mix.shell().info("  #{rehashed} rules rehashed")

    # Group by normalized hash and purge duplicates
    all_rules = Maestro.Ops.Rule.read!()

    duplicates =
      all_rules
      |> Enum.group_by(& &1.content_hash)
      |> Enum.filter(fn {_hash, rules} -> length(rules) > 1 end)

    purged =
      Enum.reduce(duplicates, 0, fn {_hash, rules}, count ->
        # Keep the best one: approved > linter > proposed > retired, then oldest
        keep =
          rules
          |> Enum.sort_by(fn r ->
            priority = %{approved: 0, linter: 1, proposed: 2, retired: 3}
            {Map.get(priority, r.status, 4), r.inserted_at}
          end)
          |> hd()

        # Merge notes from duplicates before deleting
        all_notes =
          rules
          |> Enum.map(& &1.notes)
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq()
          |> Enum.join("; ")

        if all_notes != "" and (is_nil(keep.notes) or keep.notes == "") do
          Maestro.Ops.Rule.update(keep, %{notes: all_notes})
        end

        # Delete the rest
        dupes = Enum.reject(rules, &(&1.id == keep.id))
        Enum.each(dupes, &Maestro.Ops.Rule.destroy/1)
        count + length(dupes)
      end)

    if purged > 0, do: Mix.shell().info("  #{purged} duplicate rules purged")
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

  # ── Phase 6: Write outputs ─────────────────────────────────────────

  defp write_outputs do
    rules = Maestro.Ops.Rule.approved!()

    # RULES.md — human-readable, grouped by category
    write_rules_md(rules)

    # rules.json — machine-readable for agents
    write_rules_json(rules)

    # AGENTS.md and CLAUDE.md are user-maintained — curate never touches them
  end

  defp write_rules_md(rules) do
    by_category = Enum.group_by(rules, & &1.category) |> Enum.sort_by(&elem(&1, 0))

    content =
      ["# Rules", "# Curated by Maestro · #{Date.utc_today()} · #{length(rules)} approved rules", ""] ++
      Enum.flat_map(by_category, fn {category, cat_rules} ->
        always = Enum.filter(cat_rules, &(&1.severity == :must))
        should = Enum.filter(cat_rules, &(&1.severity != :must))

        header = ["## #{category |> to_string() |> String.capitalize()}", ""]

        always_lines =
          if always != [] do
            Enum.map(always, fn r -> "**ALWAYS** #{r.content}" end)
          else
            []
          end

        should_lines = Enum.map(should, fn r -> "- #{r.content}" end)

        header ++ always_lines ++ should_lines ++ [""]
      end)

    File.write!("RULES.md", Enum.join(content, "\n"))
    Mix.shell().info("  RULES.md (#{length(rules)} rules)")
  end

  defp write_rules_json(rules) do
    json_rules =
      Enum.map(rules, fn r ->
        base = %{
          id: r.id,
          content: r.content,
          category: r.category,
          severity: r.severity
        }

        # Include fix data if present
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
    Mix.shell().info("  rules.json (#{length(rules)} rules)")
  end

  # ── Phase 7 ─────────────────────────────────────────────────────────

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

  # ── Phase 7: Quality gate ────────────────────────────────────────

  defp quality_gate do
    # Step 1: Demote approved rules that fail quality → proposed
    approved = Maestro.Ops.Rule.approved!()
    approved_results = Quality.audit_rules(approved)

    failing = Enum.reject(approved_results, & &1.pass?)
    passing = Enum.filter(approved_results, & &1.pass?)

    demoted =
      failing
      |> Enum.map(fn result ->
        rule = Maestro.Ops.Rule.by_id!(result.id)
        Maestro.Ops.Rule.reset_to_proposed(rule)
        result
      end)
      |> length()

    Mix.shell().info("  #{length(passing)} approved (pass quality)")

    if demoted > 0 do
      Mix.shell().info("  #{demoted} demoted to proposed (failed quality)")

      summary = Quality.summarize(approved_results)
      for ic <- summary.issues_by_check do
        Mix.shell().info("    #{ic.check}: #{ic.count}")
      end
    end

    # Step 2: Try to auto-fix all proposed rules (including freshly demoted) and approve
    proposed = Maestro.Ops.Rule.read!() |> Enum.filter(&(&1.status == :proposed))
    proposed_results = Quality.audit_rules(proposed)
    proposed_failing = Enum.reject(proposed_results, & &1.pass?)

    # Rules that already pass quality — just approve them
    already_passing =
      proposed_results
      |> Enum.filter(& &1.pass?)
      |> Enum.each(fn result ->
        rule = Maestro.Ops.Rule.by_id!(result.id)
        Maestro.Ops.Rule.approve(rule)
      end)
      |> then(fn _ -> Enum.count(proposed_results, & &1.pass?) end)

    if already_passing > 0 do
      Mix.shell().info("  #{already_passing} proposed rules passed quality — approved")
    end

    # Rules that fail — try to fix
    {auto_fixed, unfixable} =
      Enum.reduce(proposed_failing, {0, 0}, fn result, {fixed, skipped} ->
        rule = Maestro.Ops.Rule.by_id!(result.id)

        case Quality.fix_content(rule.content, rule) do
          {:ok, new_content} ->
            new_hash = RuleParser.content_hash(new_content)
            {:ok, updated} = Maestro.Ops.Rule.update(rule, %{content: new_content, content_hash: new_hash})
            Maestro.Ops.Rule.approve(updated)
            {fixed + 1, skipped}

          :skip ->
            {fixed, skipped + 1}
        end
      end)

    if auto_fixed > 0 do
      Mix.shell().info("  #{auto_fixed} proposed rules auto-fixed and approved")
    end

    if unfixable > 0 do
      Mix.shell().info("  #{unfixable} proposed rules need manual quality fixes")
    end
  end
end
