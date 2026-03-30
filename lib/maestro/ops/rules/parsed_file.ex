defmodule Maestro.Ops.Rules.ParsedFile do
  @moduledoc """
  A parsed source file — the single code access layer for all fixers.

  Every fixer receives a ParsedFile, never raw source strings.
  Code is accessed only through the AST fields:

  - `ast` — Sourceror-parsed Elixir AST (or nil if parse fails)
  - `heex_asts` — list of parsed HEEx template ASTs extracted from ~H sigils
  - `heex_sources` — list of raw HEEx template strings (for HEEx-aware patching)
  - `source` — original source (used only for writing patches back, never for analysis)
  """

  defstruct [:path, :rel_path, :source, :ast, :heex_sources, :heex_asts, :module_name]

  @doc """
  Parse an .ex file into a ParsedFile struct.
  All code access for fixers goes through this struct.
  """
  @spec parse(term(), term()) :: term()
  def parse(abs_path, project_path) do
    source = File.read!(abs_path)
    ast = parse_elixir(source)
    module_name = extract_module_name(ast)
    heex_sources = extract_heex_sources(source)
    heex_asts = Enum.map(heex_sources, &parse_heex/1)

    %__MODULE__{
      path: abs_path,
      rel_path: Path.relative_to(abs_path, project_path),
      source: source,
      ast: ast,
      module_name: module_name,
      heex_sources: heex_sources,
      heex_asts: heex_asts
    }
  end

  @doc "Does this file's AST contain a specific module reference?"
  @spec ast_contains_module?(term(), term()) :: term()
  def ast_contains_module?(%__MODULE__{ast: nil}, _), do: false

  @spec ast_contains_module?(term(), term()) :: term()
  def ast_contains_module?(%__MODULE__{ast: ast}, module_atom) do
    {_, found} =
      Macro.prewalk(ast, false, fn
        {:__aliases__, _, atoms} = node, acc ->
          if module_atom in atoms, do: {node, true}, else: {node, acc}

        node, acc ->
          {node, acc}
      end)

    found
  end

  @doc "Does this file's AST contain a def for the given function name?"
  @spec ast_has_def?(term(), term()) :: term()
  def ast_has_def?(%__MODULE__{ast: nil}, _), do: false

  @spec ast_has_def?(term(), term()) :: term()
  def ast_has_def?(%__MODULE__{ast: ast}, func_name) do
    {_, found} =
      Macro.prewalk(ast, false, fn
        {:def, _, [{^func_name, _, _} | _]} = node, _acc -> {node, true}
        {:def, _, [{:when, _, [{^func_name, _, _} | _]} | _]} = node, _acc -> {node, true}
        node, acc -> {node, acc}
      end)

    found
  end

  @doc "Does any HEEx template contain a specific tag (e.g. 'script', 'form')?"
  @spec heex_has_tag?(term(), term()) :: term()
  def heex_has_tag?(%__MODULE__{heex_asts: asts}, tag_name) do
    Enum.any?(asts, fn
      {:ok, tree} -> tree_has_tag?(tree, tag_name)
      _ -> false
    end)
  end

  @doc "Does any HEEx source contain a specific string? (for simple presence checks)"
  @spec heex_contains?(term(), term()) :: term()
  def heex_contains?(%__MODULE__{heex_sources: sources}, pattern) do
    Enum.any?(sources, &String.contains?(&1, pattern))
  end

  # -- Private --

  defp parse_elixir(source) do
    case Sourceror.parse_string(source) do
      {:ok, ast} -> ast
      _ -> nil
    end
  end

  defp extract_module_name(nil), do: nil

  defp extract_module_name(ast) do
    {_, name} =
      Macro.prewalk(ast, nil, fn
        {:defmodule, _, [{:__aliases__, _, parts} | _]} = node, nil ->
          {node, Enum.join(parts, ".")}

        node, acc ->
          {node, acc}
      end)

    name
  end

  defp extract_heex_sources(source) do
    Enum.map(Regex.scan(~r/~H"""(.*?)"""/s, source), fn [_, content] -> content end)
  end

  defp parse_heex(heex_source) do
    # Use the HEEx tokenizer from Phoenix LiveView
    try do
      case Phoenix.LiveView.HTMLEngine.component_to_tree(heex_source) do
        {:ok, tree} -> {:ok, tree}
        error -> error
      end
    rescue
      _ -> {:error, :parse_failed}
    end
  end

  defp tree_has_tag?(nodes, tag_name) when is_list(nodes) do
    Enum.any?(nodes, &tree_has_tag?(&1, tag_name))
  end

  defp tree_has_tag?({:tag_block, name, _attrs, children, _meta}, tag_name) do
    name == tag_name or tree_has_tag?(children, tag_name)
  end

  defp tree_has_tag?({:tag_self_close, name, _attrs}, tag_name), do: name == tag_name
  defp tree_has_tag?(_, _), do: false
end
