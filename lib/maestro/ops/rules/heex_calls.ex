defmodule Maestro.Ops.Rules.HeexCalls do
  @moduledoc """
  Extracts function calls from HEEx templates across the project.

  Giulia's dead code analysis can't see into HEEx templates — it only parses .ex files.
  This module bridges that gap by parsing all `~H` sigils with MaestroTool.HEExParser,
  extracting function references, and producing a MapSet of `{module, function}` tuples
  that should be excluded from dead code reports.
  """

  @doc """
  Scans all .ex files under `lib/` for `~H\"\"\"` blocks, parses them, and returns
  a MapSet of `{module_name, function_name}` tuples for all function calls found.
  """
  @spec extract(String.t()) :: MapSet.t()
  def extract(project_path) do
    lib_path = Path.join(project_path, "lib")

    Enum.reduce(Path.wildcard(Path.join(lib_path, "**/*.ex")), MapSet.new(), fn file, acc ->
      source = File.read!(file)
      module_name = extract_module_name(source)
      if module_name, do: extract_from_source(source, module_name, acc), else: acc
    end)
  end

  @doc """
  Filters dead code findings, removing entries that are called from HEEx templates.
  """
  @spec filter_dead_code(map(), MapSet.t()) :: map()
  def filter_dead_code(%{"dead" => dead} = results, heex_calls) do
    filtered =
      Enum.reject(dead, fn entry ->
        MapSet.member?(heex_calls, {entry["module"], entry["name"]})
      end)

    %{results | "dead" => filtered, "count" => length(filtered)}
  end

  def filter_dead_code(results, _heex_calls), do: results

  # -- Private --

  defp extract_from_source(source, module_name, acc) do
    heex_blocks = extract_heex_blocks(source)

    Enum.reduce(heex_blocks, acc, fn heex, acc ->
      calls = extract_calls_from_heex(heex)

      Enum.reduce(calls, acc, fn func_name, acc ->
        MapSet.put(acc, {module_name, func_name})
      end)
    end)
  end

  defp extract_module_name(source) do
    case Regex.run(~r/defmodule\s+([\w.]+)/, source) do
      [_, name] -> name
      _ -> nil
    end
  end

  defp extract_heex_blocks(source) do
    Enum.map(Regex.scan(~r/~H"""(.*?)"""/s, source), fn [_, content] -> content end)
  end

  defp extract_calls_from_heex(heex_source) do
    case MaestroTool.HEExParser.parse(heex_source) do
      {:ok, tree} ->
        MapSet.to_list(collect_function_calls(tree, MapSet.new()))

      {:error, _} ->
        # Fallback: regex extraction
        # Fallback: regex extraction
        Enum.map(Regex.scan(~r/\{([a-z_][a-z0-9_]*)\(/, heex_source), fn [_, name] -> name end)
    end
  end

  # -- HEEx AST walking --

  defp collect_function_calls(nodes, acc) when is_list(nodes) do
    Enum.reduce(nodes, acc, &collect_function_calls/2)
  end

  defp collect_function_calls({:body_expr, expr, _meta}, acc) do
    extract_func_names(expr, acc)
  end

  defp collect_function_calls({:eex, expr, _meta}, acc) do
    extract_func_names(expr, acc)
  end

  defp collect_function_calls({:tag_block, _name, attrs, children, _meta}, acc) do
    acc = collect_from_attrs(attrs, acc)
    collect_function_calls(children, acc)
  end

  defp collect_function_calls({:tag_self_close, _name, attrs}, acc) do
    collect_from_attrs(attrs, acc)
  end

  defp collect_function_calls({:eex_block, expr, branches, _meta}, acc) do
    acc = extract_func_names(expr, acc)

    Enum.reduce(branches, acc, fn {children, _closing}, acc ->
      collect_function_calls(children, acc)
    end)
  end

  defp collect_function_calls(_node, acc), do: acc

  defp collect_from_attrs(attrs, acc) do
    Enum.reduce(attrs, acc, fn
      {_name, {:expr, expr, _}, _meta}, a -> extract_func_names(expr, a)
      _, a -> a
    end)
  end

  @elixir_keywords ~w(if unless case cond for with do else end not and or in)

  defp extract_func_names(expr, acc) when is_binary(expr) do
    Regex.scan(~r/(?<![.@:])([a-z_][a-z0-9_]*[!?]?)\s*\(/, expr)
    |> Enum.map(fn [_, name] -> name end)
    |> Enum.reject(&(&1 in @elixir_keywords))
    |> Enum.reduce(acc, &MapSet.put(&2, &1))
  end

  defp extract_func_names(_, acc), do: acc
end
