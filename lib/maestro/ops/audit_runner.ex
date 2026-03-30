defmodule Maestro.Ops.AuditRunner do
  @moduledoc """
  Executes a full audit run across all project modules.

  Combines multiple audit strategies:
  - **Rule audit** — checks modules against approved/proposed/linter rules
  - **Deep audit** — AST analysis via Giulia daemon (dead code, god modules, complexity, conventions)

  The runner owns the orchestration: discover modules, apply strategies, merge findings,
  persist results. Callers (LiveViews, mix tasks) just pass options and get back an Audit.
  """

  alias Maestro.Ops.{Audit, AuditResult, Rule}
  alias Maestro.Ops.Rules.{SiteAudit, GiuliaClient}

  @project_path File.cwd!()

  @doc """
  Runs a full audit with the given strategy flags.

  Options:
  - `:approved` — include approved rules (default true)
  - `:proposed` — include proposed rules (default false)
  - `:linter` — include linter rules (default true)
  - `:deep` — run Giulia AST analysis (default: auto-detect availability)
  - `:project_path` — override project path (default: cwd)

  Returns `{:ok, audit}` or `{:error, reason}`.
  """
  @spec run(term()) :: term()
  def run(opts \\ []) do
    project_path = Keyword.get(opts, :project_path, @project_path)
    deep? = Keyword.get(opts, :deep, GiuliaClient.available?())

    total_modules = length(Path.wildcard(Path.join(project_path, "lib/**/*.ex")))
    {:ok, audit} = Audit.create(%{total_modules: total_modules}, authorize?: false)

    try do
      maestro_by_module = run_rule_audit(project_path, opts)
      giulia_by_module = if deep?, do: run_deep_audit(project_path), else: %{}
      persist_merged_results(audit, maestro_by_module, giulia_by_module)
      Audit.complete(audit, %{}, authorize?: false)
      {:ok, audit}
    rescue
      e ->
        Audit.fail(audit, %{}, authorize?: false)
        {:error, e}
    end
  end

  @doc """
  Returns whether the deep audit strategy (Giulia) is available.
  """
  @spec deep_audit_available?() :: term()
  def deep_audit_available?, do: GiuliaClient.available?()

  @doc """
  Fetches module dependency graph for a given module.
  Returns a mermaid graph string or nil.
  """
  @spec fetch_module_dag(term(), term()) :: term()
  def fetch_module_dag(module_name, project_path \\ nil) do
    project_path = project_path || @project_path
    deps = GiuliaClient.fetch_dependencies(project_path, module_name)
    dependents = GiuliaClient.fetch_dependents(project_path, module_name)

    if deps == [] and dependents == [] do
      nil
    else
      short = &short_module/1
      center = short.(module_name)

      lines =
        Enum.map(dependents, fn d -> "  #{short.(d)} --> #{center}" end) ++
          Enum.map(deps, fn d -> "  #{center} --> #{short.(d)}" end)

      "graph LR\n  style #{safe_mermaid_id(center)} fill:#f66,stroke:#333\n" <>
        Enum.join(lines, "\n")
    end
  end

  # -- Rule audit strategy --

  defp run_rule_audit(project_path, opts) do
    pages =
      SiteAudit.discover_modules(project_path) ++
        SiteAudit.discover_pages(MaestroWeb.Router, MaestroWeb)

    pages = Enum.uniq_by(pages, & &1.module)

    statuses =
      (if(Keyword.get(opts, :approved, true), do: [:approved], else: []) ++
         if(Keyword.get(opts, :proposed, false), do: [:proposed], else: [])) ++
        if Keyword.get(opts, :linter, true), do: [:linter], else: []

    all_rules = Enum.filter(Rule.read!(), &(&1.status in statuses))
    page_results = SiteAudit.audit_pages(pages, all_rules)

    Map.new(page_results, fn pr ->
      {inspect(pr.module),
       %{
         path: pr.path,
         source_file: pr.source_file,
         findings:
           Enum.map(pr.findings, fn f -> Map.new(f, fn {k, v} -> {to_string(k), v} end) end)
       }}
    end)
  end

  # -- Deep audit strategy (Giulia) --

  defp run_deep_audit(project_path) do
    GiuliaClient.scan_and_wait(project_path)

    Map.new(GiuliaClient.pull_all(project_path), fn gr ->
      {gr.module_name, %{path: gr.path, source_file: gr.source_file, findings: gr.findings}}
    end)
  end

  # -- Merge & persist --

  defp persist_merged_results(audit, maestro_by_module, giulia_by_module) do
    all_module_names =
      MapSet.union(
        MapSet.new(Map.keys(maestro_by_module)),
        MapSet.new(Map.keys(giulia_by_module))
      )

    for mod <- all_module_names do
      maestro = Map.get(maestro_by_module, mod, %{findings: []})
      giulia = Map.get(giulia_by_module, mod, %{findings: []})

      merged_findings = maestro.findings ++ giulia.findings
      fail_count = Enum.count(merged_findings, &(not &1["pass?"]))

      if fail_count > 0 do
        pass_count = Enum.count(merged_findings, & &1["pass?"])

        score =
          if fail_count + pass_count > 0,
            do: round(pass_count / (fail_count + pass_count) * 100),
            else: 100

        path = Map.get(maestro, :path) || Map.get(giulia, :path) || mod
        source_file = Map.get(maestro, :source_file) || Map.get(giulia, :source_file)

        AuditResult.create!(
          %{
            audit_id: audit.id,
            path: path,
            module_name: mod,
            source_file: source_file,
            score: score,
            pass: pass_count,
            fail: fail_count,
            skip: 0,
            total: length(merged_findings),
            findings: merged_findings
          },
          authorize?: false
        )
      end
    end
  end

  defp short_module(name) do
    name |> String.split(".") |> List.last()
  end

  defp safe_mermaid_id(name) do
    String.replace(name, ~r/[^a-zA-Z0-9_]/, "_")
  end
end
