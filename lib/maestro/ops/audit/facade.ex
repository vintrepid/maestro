defmodule Maestro.Ops.Audit.Facade do
  require Logger
  @moduledoc """
  Facade API for the Audit domain.

  All audit operations — querying, running, fixing, subscribing — go through here.
  LiveViews and mix tasks alias this module as `Audit`. This separation exists because
  Ash resources can't use `Ash.Query` on themselves during compilation (cyclic struct expansion).
  """

  require Ash.Query

  alias Maestro.Ops.{Audit, AuditResult, AuditRunner, Rule}
  alias Maestro.Ops.Rules.Fixer

  @aggregates [:total_results, :total_fail, :total_pass_checks, :avg_score, :total_pass_modules]
  @project_base Path.expand("~/dev")

  @spec projects() :: [map()]
  def projects do
    Maestro.Ops.Project.active!(authorize?: false)
  end

  defp project_path(slug), do: Path.join(@project_base, slug)

  @doc "Returns the default project to show in the audit UI. Prefers the project with the most recent completed audit."
  @spec default_project([map()]) :: map() | nil
  def default_project(projects) do
    # Find which project has the most recent completed audit
    projects
    |> Enum.map(fn p ->
      latest = latest_completed(to_string(p.id))
      {p, latest && latest.inserted_at}
    end)
    |> Enum.reject(fn {_p, ts} -> is_nil(ts) end)
    |> Enum.sort_by(fn {_p, ts} -> ts end, {:desc, DateTime})
    |> List.first()
    |> case do
      {project, _} -> project
      nil -> List.first(projects)
    end
  end

  @spec subscribe() :: term()
  def subscribe do
    Phoenix.PubSub.subscribe(Maestro.PubSub, Maestro.Ops.AuditPubSub.topic())
  end

  @spec latest_completed(String.t() | nil) :: term()
  def latest_completed(project_id \\ nil) do
    Audit
    |> Ash.Query.filter(status == :completed)
    |> filter_by_project(project_id)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(1)
    |> Ash.read!(load: @aggregates)
    |> List.first()
  end

  @spec results_query(term()) :: term()
  def results_query(nil) do
    Ash.Query.filter(AuditResult, false)
  end

  @spec results_query(term()) :: term()
  def results_query(%{id: audit_id}) do
    AuditResult
    |> Ash.Query.filter(audit_id == ^audit_id)
    |> Ash.Query.sort(score: :asc)
  end

  @spec category_summary(term()) :: term()
  def category_summary(nil), do: []

  @spec category_summary(term()) :: term()
  def category_summary(%{id: audit_id}) do
    AuditResult
    |> Ash.Query.filter(audit_id == ^audit_id)
    |> Ash.read!()
    |> Enum.flat_map(fn r ->
      Enum.map(r.findings, fn f ->
        {f["rule_category"] || "unknown", r.module_name}
      end)
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.map(fn {category, modules} ->
      {category, %{count: length(modules), modules: Enum.uniq(modules)}}
    end)
    |> Enum.sort_by(fn {_, %{count: c}} -> -c end)
  end

  @spec find_result(term()) :: term()
  def find_result(id) do
    results = AuditResult.read!()
    Enum.find(results, &(to_string(&1.id) == to_string(id)))
  end

  @spec result_exists?(term(), term()) :: term()
  def result_exists?(%{id: audit_id}, module_name) do
    AuditResult
    |> Ash.Query.filter(audit_id == ^audit_id and module_name == ^module_name)
    |> Ash.read!()
    |> Enum.any?()
  end

  @doc """
  Returns a diff summary comparing two audit runs.
  Shows new rules, resolved findings, and files affected.
  """
  @spec diff_audits(term(), term()) :: term()
  def diff_audits(nil, _current), do: %{new_findings: [], resolved_findings: [], files_changed: []}
  def diff_audits(_previous, nil), do: %{new_findings: [], resolved_findings: [], files_changed: []}

  def diff_audits(%{id: prev_id}, %{id: curr_id}) do
    prev_results =
      AuditResult
      |> Ash.Query.filter(audit_id == ^prev_id)
      |> Ash.read!()

    curr_results =
      AuditResult
      |> Ash.Query.filter(audit_id == ^curr_id)
      |> Ash.read!()

    prev_keys = finding_keys(prev_results)
    curr_keys = finding_keys(curr_results)

    new_findings =
      MapSet.difference(curr_keys, prev_keys)
      |> MapSet.to_list()
      |> Enum.sort()

    resolved_findings =
      MapSet.difference(prev_keys, curr_keys)
      |> MapSet.to_list()
      |> Enum.sort()

    prev_modules = MapSet.new(prev_results, & &1.module_name)
    curr_modules = MapSet.new(curr_results, & &1.module_name)

    files_changed =
      MapSet.union(
        MapSet.difference(curr_modules, prev_modules),
        MapSet.difference(prev_modules, curr_modules)
      )
      |> MapSet.to_list()
      |> Enum.sort()

    %{
      new_findings: new_findings,
      resolved_findings: resolved_findings,
      files_changed: files_changed,
      prev_total_fail: Enum.sum(Enum.map(prev_results, & &1.fail)),
      curr_total_fail: Enum.sum(Enum.map(curr_results, & &1.fail)),
      new_rules: new_rule_ids(prev_results, curr_results)
    }
  end

  defp finding_keys(results) do
    results
    |> Enum.flat_map(fn r ->
      Enum.map(r.findings, fn f ->
        {r.module_name, f["rule_id"] || f["rule_category"], List.first(f["evidence"] || [])}
      end)
    end)
    |> MapSet.new()
  end

  defp new_rule_ids(prev_results, curr_results) do
    prev_ids =
      prev_results
      |> Enum.flat_map(fn r -> Enum.map(r.findings, &(&1["rule_id"])) end)
      |> MapSet.new()

    curr_results
    |> Enum.flat_map(fn r -> Enum.map(r.findings, &(&1["rule_id"])) end)
    |> MapSet.new()
    |> MapSet.difference(prev_ids)
    |> MapSet.to_list()
    |> Enum.sort()
  end

  @doc """
  Returns the two most recent completed audits for diffing.
  """
  @spec latest_two_completed(String.t() | nil) :: term()
  def latest_two_completed(project_id \\ nil) do
    Audit
    |> Ash.Query.filter(status == :completed)
    |> filter_by_project(project_id)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(2)
    |> Ash.read!(load: @aggregates)
  end

  @spec run_audit(term()) :: term()
  def run_audit(opts) do
    result =
      case Keyword.get(opts, :project_id) do
        nil ->
          AuditRunner.run(opts)

        project_id ->
          project = Maestro.Ops.Project.by_id!(project_id, authorize?: false)

          opts
          |> Keyword.put(:project_path, project_path(project.slug))
          |> AuditRunner.run()
      end

    # Auto-fix only if audit completed — don't fix on partial/failed results
    with {:ok, audit} <- result do
      audit = Ash.reload!(audit, authorize?: false)

      if audit.status == :completed do
        case fix_all(audit) do
          {:ok, fixed_count} ->
            Logger.info("Auto-fixed #{fixed_count} file(s) after audit ##{audit.id}")

          {:error, reason} ->
            Logger.warning("Auto-fix errors after audit ##{audit.id}: #{inspect(reason)}")
        end
      else
        Logger.warning("Audit ##{audit.id} failed — skipping auto-fix. Notes: #{audit.notes}")
      end

      {:ok, audit}
    end
  end

  @spec deep_audit_available?() :: term()
  def deep_audit_available?, do: AuditRunner.deep_audit_available?()

  @spec fetch_module_dag(term()) :: term()
  def fetch_module_dag(module_name), do: AuditRunner.fetch_module_dag(module_name)

  @spec fix_all(term()) :: term()
  def fix_all(audit) do
    audit = Ash.load!(audit, [:project], authorize?: false)
    path = if audit.project, do: project_path(audit.project.slug), else: File.cwd!()

    results =
      AuditResult
      |> Ash.Query.filter(audit_id == ^audit.id)
      |> Ash.read!()

    all_rules = Enum.filter(Rule.read!(), &(&1.status in [:approved, :linter]))
    rules_by_id = Map.new(all_rules, &{&1.id, &1})

    # Snapshot file mtimes before fixing (Giulia fixes write files directly)
    all_files =
      results
      |> Enum.map(& &1.source_file)
      |> Enum.reject(&is_nil/1)
      |> Enum.filter(&File.exists?/1)

    mtimes_before = Map.new(all_files, fn f -> {f, file_mtime(f)} end)

    igniter = Map.put(Igniter.new(), :root, path)

    {updated_igniter, errors} =
      Enum.reduce(results, {igniter, []}, fn ar, {ign, errs} ->
        pr = %{
          path: ar.path,
          module: Module.concat([ar.module_name]),
          source_file: ar.source_file,
          findings: Enum.map(ar.findings, &atomize_finding/1)
        }

        case Fixer.fix_page(ign, pr, rules_by_id) do
          {:ok, new_ign} -> {new_ign, errs}
          {:error, reason} -> {ign, [{ar.path, reason} | errs]}
        end
      end)

    if errors != [] do
      error_notes = Enum.map_join(errors, "\n", fn {path, reason} ->
        "#{path}: #{inspect(reason)}"
      end)

      Logger.warning("Fixer errors:\n#{error_notes}")
    end

    # Write Igniter-tracked changes (Maestro rule fixes)
    sources = updated_igniter.rewrite.sources
    igniter_changed = Enum.filter(sources, fn {_path, source} -> Rewrite.Source.updated?(source) end)

    for {path, source} <- igniter_changed do
      content = Rewrite.Source.get(source, :content)
      File.write!(path, content)
    end

    # Count all files that changed (Igniter + direct writes from Giulia fixes)
    direct_changed =
      Enum.count(all_files, fn f ->
        file_mtime(f) != mtimes_before[f]
      end)

    {:ok, length(igniter_changed) + direct_changed}
  end

  defp file_mtime(path) do
    case File.stat(path) do
      {:ok, %{mtime: mtime}} -> mtime
      _ -> nil
    end
  end

  defp filter_by_project(query, nil), do: Ash.Query.filter(query, is_nil(project_id))
  defp filter_by_project(query, id), do: Ash.Query.filter(query, project_id == ^id)

  defp atomize_finding(f) when is_map(f) do
    base = %{
      rule_id: f["rule_id"],
      rule_content: f["rule_content"],
      rule_category: f["rule_category"],
      pass?: f["pass?"],
      evidence: f["evidence"] || []
    }

    # Restore check_module and violations for the fixer path
    base =
      case f["check_module"] do
        mod when is_binary(mod) and mod != "" ->
          Map.put(base, :check_module, String.to_existing_atom(mod))
        _ -> base
      end

    case f["violations"] do
      violations when is_list(violations) and violations != [] ->
        atomized = Enum.map(violations, fn v ->
          Map.new(v, fn
            {k, val} when is_binary(k) -> {String.to_existing_atom(k), val}
            {k, val} -> {k, val}
          end)
        end)
        Map.put(base, :violations, atomized)
      _ -> base
    end
  end
end
