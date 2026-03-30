defmodule Maestro.Ops.Rules.GiuliaClient do
  @moduledoc """
  HTTP client for Giulia code intelligence daemon.

  Scans a project and pulls AST-level analysis: dead code, god modules,
  complexity, conventions. Returns normalized findings compatible with
  AuditResult storage.
  """

  @base_url "http://localhost:4020"

  @scan_wait_ms 2_000
  @max_scan_polls 15
  # Host ~/dev is mounted as /projects in the Giulia container
  @host_prefix "/Users/vince/dev/"
  @container_prefix "/projects/"

  @doc "Fetches all skills from the Giulia discovery API."
  @spec fetch_skills(term()) :: term()
  def fetch_skills(category \\ nil) do
    params = if category, do: [category: category], else: []

    case Req.get("#{@base_url}/api/discovery/skills", params: params, receive_timeout: 5_000) do
      {:ok, %{status: 200, body: %{"skills" => skills}}} -> skills
      _ -> []
    end
  end

  @doc "Fetches skill categories with counts."
  @spec fetch_categories() :: term()
  def fetch_categories do
    case Req.get("#{@base_url}/api/discovery/categories", receive_timeout: 3_000) do
      {:ok, %{status: 200, body: %{"categories" => cats}}} -> cats
      _ -> []
    end
  end

  @doc "Searches skills by keyword."
  @spec search_skills(term()) :: term()
  def search_skills(query) do
    case Req.get("#{@base_url}/api/discovery/search",
           params: [q: query],
           receive_timeout: 3_000
         ) do
      {:ok, %{status: 200, body: %{"skills" => skills}}} -> skills
      _ -> []
    end
  end

  @spec available?() :: term()
  def available? do
    case Req.get("#{@base_url}/health", receive_timeout: 3_000) do
      {:ok, %{status: 200}} -> true
      _ -> false
    end
  end

  @spec scan_and_wait(any()) :: term()
  def scan_and_wait(project_path) do
    container_path = to_container_path(project_path)

    Req.post!("#{@base_url}/api/index/scan",
      json: %{path: container_path},
      receive_timeout: 10_000
    )

    wait_for_scan(container_path, 0)
  end

  defp wait_for_scan(_path, attempt) when attempt >= @max_scan_polls, do: :ok

  defp wait_for_scan(path, attempt) do
    case Req.get("#{@base_url}/api/index/status", params: [path: path], receive_timeout: 5_000) do
      {:ok, %{status: 200, body: %{"status" => "idle", "file_count" => count}}} when count > 0 ->
        :ok

      _ ->
        Process.sleep(@scan_wait_ms)
        wait_for_scan(path, attempt + 1)
    end
  end

  @spec pull_all(any()) :: term()
  def pull_all(project_path) do
    container_path = to_container_path(project_path)

    results = %{
      dead_code: fetch_dead_code(container_path),
      god_modules: fetch_god_modules(container_path),
      complexity: fetch_complexity(container_path),
      conventions: fetch_conventions(container_path)
    }

    # Filter dead code false positives: functions called from HEEx templates
    heex_calls = Maestro.Ops.Rules.HeexCalls.extract(project_path)
    results = %{results | dead_code: Maestro.Ops.Rules.HeexCalls.filter_dead_code(results.dead_code, heex_calls)}

    normalize_to_audit_results(results)
  end

  defp fetch_dead_code(path) do
    case Req.get("#{@base_url}/api/knowledge/dead_code",
           params: [path: path],
           receive_timeout: 15_000
         ) do
      {:ok, %{status: 200, body: body}} -> body
      _ -> %{"dead" => [], "count" => 0}
    end
  end

  defp fetch_god_modules(path) do
    case Req.get("#{@base_url}/api/knowledge/god_modules",
           params: [path: path],
           receive_timeout: 15_000
         ) do
      {:ok, %{status: 200, body: body}} -> body
      _ -> %{"modules" => [], "count" => 0}
    end
  end

  defp fetch_complexity(path) do
    case Req.get("#{@base_url}/api/index/complexity",
           params: [path: path, min: 8, limit: 50],
           receive_timeout: 15_000
         ) do
      {:ok, %{status: 200, body: body}} -> body
      _ -> %{"functions" => [], "count" => 0}
    end
  end

  @spec fetch_conventions(term()) :: term()
  def fetch_conventions(path) do
    case Req.get("#{@base_url}/api/knowledge/conventions",
           params: [path: path],
           receive_timeout: 15_000
         ) do
      {:ok, %{status: 200, body: body}} -> body
      _ -> %{"by_category" => %{}, "total_violations" => 0}
    end
  end

  @spec fetch_dependencies(term(), term()) :: term()
  def fetch_dependencies(project_path, module_name) do
    container_path = to_container_path(project_path)

    case Req.get("#{@base_url}/api/knowledge/dependencies",
           params: [path: container_path, module: module_name],
           receive_timeout: 5_000
         ) do
      {:ok, %{status: 200, body: %{"dependencies" => d}}} -> d
      _ -> []
    end
  end

  @spec fetch_dependents(term(), term()) :: term()
  def fetch_dependents(project_path, module_name) do
    container_path = to_container_path(project_path)

    case Req.get("#{@base_url}/api/knowledge/dependents",
           params: [path: container_path, module: module_name],
           receive_timeout: 5_000
         ) do
      {:ok, %{status: 200, body: %{"dependents" => d}}} -> d
      _ -> []
    end
  end

  @doc """
  Normalizes Giulia results into per-module AuditResult-compatible maps.

  Returns a list of `%{path, module_name, source_file, score, pass, fail, findings}`.
  Each module that appears in any Giulia endpoint gets one result row.
  """
  @spec normalize_to_audit_results(any()) :: term()
  def normalize_to_audit_results(results) do
    modules = collect_modules(results)

    Enum.sort_by(
      Enum.map(modules, fn {module_name, data} ->
        findings = data.findings
        fail_count = Enum.count(findings, &(not &1["pass?"]))
        # Score: 100 = clean, decreases by ~15 points per issue, floor at 0
        score = max(0, 100 - fail_count * 15)
        file = normalize_path(data.file)

        %{
          path: file || module_name,
          module_name: module_name,
          source_file: file,
          score: score,
          pass: 0,
          fail: fail_count,
          skip: 0,
          total: fail_count,
          findings: findings
        }
      end),
      & &1.score
    )
  end

  @spec to_container_path(any()) :: term()
  def to_container_path(host_path) do
    if String.starts_with?(host_path, @host_prefix) do
      @container_prefix <> String.trim_leading(host_path, @host_prefix)
    else
      host_path
    end
  end

  # Giulia returns container paths like /projects/maestro/lib/...
  # Normalize to relative paths like lib/...
  defp normalize_path(nil), do: nil

  defp normalize_path(path) do
    case Regex.run(~r{/projects/[^/]+/(.+)}, path) do
      [_, relative] -> relative
      _ -> path
    end
  end

  defp collect_modules(results) do
    acc = %{}

    acc = add_dead_code_findings(acc, results.dead_code)
    acc = add_god_module_findings(acc, results.god_modules)
    acc = add_complexity_findings(acc, results.complexity)
    acc = add_convention_findings(acc, results.conventions)

    acc
  end

  defp ensure_module(acc, module_name, file) do
    Map.put_new(acc, module_name, %{file: normalize_path(file), findings: []})
  end

  defp add_finding(acc, module_name, finding) do
    update_in(acc, [module_name, :findings], &[finding | &1])
  end

  defp add_dead_code_findings(acc, %{"dead" => dead}) do
    Enum.reduce(dead, acc, fn entry, acc ->
      mod = entry["module"]
      file = entry["file"]
      func = "#{entry["name"]}/#{entry["arity"]}"

      add_finding(ensure_module(acc, mod, file), mod, %{
        "pass?" => false,
        "rule_category" => "dead_code",
        "rule_content" => "Dead function: #{func} (defined but never called)",
        "evidence" => ["#{entry["type"]} #{func} at line #{entry["line"]}"],
        "rule_id" => nil
      })
    end)
  end

  defp add_dead_code_findings(acc, _), do: acc

  defp add_god_module_findings(acc, %{"modules" => modules}) do
    Enum.reduce(modules, acc, fn entry, acc ->
      mod = entry["module"]
      file = entry["file"]
      score = entry["score"]

      severity =
        cond do
          score >= 150 -> "critical"
          score >= 100 -> "high"
          true -> "moderate"
        end

      add_finding(ensure_module(acc, mod, file), mod, %{
        "pass?" => false,
        "rule_category" => "god_module",
        "rule_content" =>
          "God module (#{severity}): score #{score}, complexity #{entry["complexity"]}, #{entry["functions"]} functions",
        "evidence" => [
          "Complexity: #{entry["complexity"]}",
          "Functions: #{entry["functions"]}",
          "Centrality: #{entry["centrality"]}"
        ],
        "rule_id" => nil
      })
    end)
  end

  defp add_god_module_findings(acc, _), do: acc

  defp add_complexity_findings(acc, %{"functions" => functions}) do
    Enum.reduce(functions, acc, fn entry, acc ->
      mod = entry["module"]
      file = entry["file"]
      func = "#{entry["name"]}/#{entry["arity"]}"
      complexity = entry["complexity"]

      add_finding(ensure_module(acc, mod, file), mod, %{
        "pass?" => false,
        "rule_category" => "complexity",
        "rule_content" => "High complexity: #{func} has cognitive complexity #{complexity}",
        "evidence" => [
          "#{entry["type"]} #{func} at line #{entry["line"]}, complexity: #{complexity}"
        ],
        "rule_id" => nil
      })
    end)
  end

  defp add_complexity_findings(acc, _), do: acc

  defp add_convention_findings(acc, %{"by_category" => by_category}) do
    Enum.reduce(by_category, acc, fn {category, violations}, acc ->
      Enum.reduce(violations, acc, fn entry, acc ->
        mod = entry["module"]
        file = entry["file"]

        add_finding(ensure_module(acc, mod, file), mod, %{
          "pass?" => false,
          "rule_category" => "convention:#{category}",
          "rule_content" => entry["message"] || "Convention violation: #{entry["rule"]}",
          "evidence" => ["Line #{entry["line"]}: #{entry["rule"]}"],
          "rule_id" => nil
        })
      end)
    end)
  end

  defp add_convention_findings(acc, _), do: acc

end
