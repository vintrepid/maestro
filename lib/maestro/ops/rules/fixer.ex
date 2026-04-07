defmodule Maestro.Ops.Rules.Fixer do
  @moduledoc """
  Applies rule fixes to source files using Igniter for AST-based code modification.

  Handles two kinds of findings:
  - **Maestro rule findings** — have a `rule_id` pointing to a Rule with a `fix_type`
  - **Giulia convention findings** — have `rule_id: nil`, keyed by `rule_category` and evidence pattern
  """

  alias Igniter.Code.{Function, Common}
  require Logger

  # Gate: every source write goes through validation. If the output doesn't parse,
  # we refuse to write it. This makes it impossible for fixers to produce invalid code.
  defp write_validated_source!(source_file, new_source) do
    case Sourceror.parse_string(new_source) do
      {:ok, _ast} ->
        File.write!(source_file, new_source)

      {:error, error} ->
        Logger.error(
          "Fixer refused to write invalid source to #{source_file}: #{inspect(error)}"
        )

        {:error, {:invalid_output, source_file, error}}
    end
  end

  # Reads a source file, returning {:ok, source} or {:error, {:file_not_found, path}}.
  # Never swallows missing files — callers propagate the error.
  defp read_source(nil), do: {:ok, nil}

  defp read_source(path) do
    if File.exists?(path) do
      {:ok, File.read!(path)}
    else
      {:error, {:file_not_found, path}}
    end
  end

  @doc """
  Applies a Maestro rule's fix to a module. Returns {:ok, igniter} or {:error, reason}.
  """
  @spec fix_it(Igniter.t(), map(), module()) :: {:ok, Igniter.t()} | {:error, String.t()}
  def fix_it(igniter, rule, module_name) do
    case rule.fix_type do
      :add_callback -> add_callback(igniter, module_name, rule.fix_target, rule.fix_template)
      :add_to_mount -> add_to_mount(igniter, module_name, rule.fix_template)
      :extract_css -> {:ok, igniter}
      :replace_pattern -> {:ok, igniter}
      :remove_pattern -> {:ok, igniter}
      :wrap_pattern -> {:ok, igniter}
      nil -> {:error, "No fix_type set on rule"}
      _ -> {:error, "Unknown fix_type"}
    end
  end

  @doc """
  Applies all fixable violations on a page result. Handles both Maestro rules and
  Giulia convention findings. Returns {:ok, igniter}.
  """
  @spec fix_page(Igniter.t(), map(), map()) :: {:ok, Igniter.t()} | {:error, term()}
  def fix_page(igniter, page_result, rules_by_id) do
    failed = Enum.reject(page_result.findings, & &1.pass?)

    # 1. Fix findings that carry a check_module with fix/2 — targeted, no re-parse
    {module_fixable, remaining} =
      Enum.split_with(failed, fn f ->
        mod = Map.get(f, :check_module)
        violations = Map.get(f, :violations, [])
        mod && violations != [] && Enum.any?(violations, & &1[:fixable]) &&
          function_exported?(mod, :fix, 2)
      end)

    with {:ok, igniter} <- fix_with_check_modules(igniter, module_fixable, page_result) do
      # 2. Fix Maestro rule findings
      maestro_fixable =
        Enum.filter(remaining, fn f ->
          rule = rules_by_id[f.rule_id]
          rule && rule.fix_type in [:add_callback]
        end)

      {igniter, errors} =
        Enum.reduce(maestro_fixable, {igniter, []}, fn finding, {ign, errs} ->
          rule = rules_by_id[finding.rule_id]

          case fix_it(ign, rule, page_result.module) do
            {:ok, new_ign} -> {new_ign, errs}
            {:error, reason} -> {ign, [reason | errs]}
          end
        end)

      # 3. Fix Giulia convention findings (no rule_id)
      giulia_fixable =
        Enum.filter(remaining, fn f ->
          is_nil(f.rule_id) and fixable_giulia_finding?(f)
        end)

      {igniter, errors} =
        Enum.reduce(giulia_fixable, {igniter, errors}, fn finding, {ign, errs} ->
          case fix_giulia_finding(ign, finding, page_result) do
            {:ok, new_ign} -> {new_ign, errs}
            {:error, reason} -> {ign, [reason | errs]}
          end
        end)

      if errors == [] do
        {:ok, igniter}
      else
        {:error, errors}
      end
    end
  end

  # Apply fixes via check_module.fix/2 — one violation at a time, no re-parse needed.
  # The check already found the violation; the fix acts on exactly that location.
  defp fix_with_check_modules(igniter, findings, page_result) do
    source_file = page_result.source_file

    with {:ok, source} when not is_nil(source) <- read_source(source_file) do
      new_source =
        Enum.reduce(findings, source, fn finding, src ->
          mod = finding.check_module
          fixable_violations = Enum.filter(finding.violations, & &1[:fixable])

          Enum.reduce(fixable_violations, src, fn violation, s ->
            try do
              fixed = mod.fix(s, violation)

              case Sourceror.parse_string(fixed) do
                {:ok, _} -> fixed
                {:error, _} ->
                  Logger.warning("Fix produced invalid source for #{inspect(mod)}, skipping violation at line #{violation[:line]}")
                  s
              end
            rescue
              e ->
                Logger.warning("Fix crashed for #{inspect(mod)} at line #{violation[:line]}: #{Exception.message(e)}")
                s
            end
          end)
        end)

      if new_source != source do
        write_validated_source!(source_file, new_source)
      end

      {:ok, igniter}
    end
  end

  # -- Giulia finding fixes --

  @giulia_fixable_patterns ["missing_spec", "missing_moduledoc", "single_value_pipe", "runtime_atom_creation"]

  defp fixable_giulia_finding?(finding) do
    evidence = List.first(finding.evidence || []) || ""
    Enum.any?(@giulia_fixable_patterns, &String.contains?(evidence, &1))
  end

  @spec fix_giulia_finding(Igniter.t(), map(), map()) :: {:ok, Igniter.t()}
  defp fix_giulia_finding(igniter, finding, page_result) do
    evidence = List.first(finding.evidence || []) || ""

    cond do
      String.contains?(evidence, "missing_spec") ->
        add_spec_from_finding(igniter, finding, page_result)

      String.contains?(evidence, "missing_moduledoc") ->
        add_moduledoc_from_finding(igniter, finding, page_result)

      String.contains?(evidence, "single_value_pipe") ->
        fix_single_pipe(igniter, finding, page_result)

      String.contains?(evidence, "runtime_atom_creation") ->
        fix_runtime_atom(igniter, finding, page_result)

      true ->
        {:ok, igniter}
    end
  end

  # Parse "Module.func/arity has no @spec" and generate a stub spec
  defp add_spec_from_finding(igniter, finding, page_result) do
    case parse_spec_finding(finding.rule_content) do
      {:ok, func_name, arity} ->
        add_spec(igniter, page_result.source_file, func_name, arity)

      :error ->
        {:ok, igniter}
    end
  end

  defp parse_spec_finding(content) when is_binary(content) do
    case Regex.run(~r/\.(\w+[!?]?)\/(\d+) has no @spec/, content) do
      [_, name, arity] ->
        {:ok, String.to_existing_atom(name), String.to_integer(arity)}

      _ ->
        :error
    end
  end

  defp parse_spec_finding(_), do: :error

  # Insert @spec stub before the function def using Sourceror
  defp add_spec(igniter, source_file, func_name, arity) do
    with {:ok, source} <- read_source(source_file) do
      if String.contains?(source, "@spec #{func_name}(") do
        {:ok, igniter}
      else
        params = Enum.join(List.duplicate("term()", arity), ", ")
        spec_line = "  @spec #{func_name}(#{params}) :: term()"

        updated =
          source
          |> String.split("\n")
          |> insert_spec_before_def(func_name, arity, spec_line)
          |> Enum.join("\n")

        if updated != source do
          write_validated_source!(source_file, updated)
        end

        {:ok, igniter}
      end
    end
  end

  defp insert_spec_before_def(lines, func_name, arity, spec_line) do
    # Match both `def func(` and `def func do` (zero-arity without parens)
    func_name_escaped = Regex.escape(to_string(func_name))
    func_with_parens = ~r/^\s*def[p]?\s+#{func_name_escaped}\s*\(/
    func_no_parens = ~r/^\s*def[p]?\s+#{func_name_escaped}\s*[,\n]|\s*def[p]?\s+#{func_name_escaped}\s+do\b/

    {result, _inserted} =
      Enum.reduce(lines, {[], false}, fn line, {acc, already_inserted_here} ->
        matches =
          not already_inserted_here and
            not prev_line_is_spec?(acc) and
            (match_with_arity?(line, func_with_parens, arity) or
               (arity == 0 and Regex.match?(func_no_parens, line)))

        if matches do
          {[line, spec_line | acc], true}
        else
          {[line | acc], false}
        end
      end)

    Enum.reverse(result)
  end

  defp match_with_arity?(line, pattern, arity) do
    if Regex.match?(pattern, line) do
      case Regex.run(~r/\(([^)]*)\)/, line) do
        [_, ""] -> arity == 0
        [_, params] -> length(String.split(params, ",")) == arity
        _ -> true
      end
    else
      false
    end
  end

  defp prev_line_is_spec?(acc) do
    case acc do
      [prev | _] -> String.contains?(prev, "@spec ")
      _ -> false
    end
  end

  # -- Moduledoc fix --

  # Patterns for modules that get @moduledoc false
  @internal_patterns [
    ~r/\.Changes\./,
    ~r/\.Senders\./,
    ~r/\.Cldr$/,
    ~r/\.Mailer$/,
    ~r/\.Repo$/,
    ~r/\.Endpoint$/,
    ~r/\.Router$/,
    ~r/\.Telemetry$/,
    ~r/\.Application$/,
    ~r/\.Secrets$/,
    ~r/\.AuthOverrides$/,
    ~r/\.ErrorJSON$/,
    ~r/\.ErrorHTML$/,
    ~r/HTML$/,
    ~r/\.PageController$/
  ]

  defp add_moduledoc_from_finding(igniter, _finding, page_result) do
    with {:ok, source} <- read_source(page_result.source_file) do
      if source =~ ~r/@moduledoc/ do
        {:ok, igniter}
      else
        module_name = String.replace_prefix(to_string(page_result.module), "Elixir.", "")
        doc = generate_moduledoc(module_name, source)

        doc_code =
          if doc == "false",
            do: "  @moduledoc false",
            else: "  @moduledoc \"\"\"\n  #{doc}\n  \"\"\""

        case Igniter.Project.Module.find_and_update_module(
               igniter,
               page_result.module,
               fn zipper ->
                 {:ok, Common.add_code(zipper, doc_code, placement: :before)}
               end
             ) do
          {:ok, new_ign} -> {:ok, new_ign}
          _ -> {:ok, igniter}
        end
      end
    end
  end

  defp generate_moduledoc(module_name, source) do
    cond do
      Enum.any?(@internal_patterns, &Regex.match?(&1, module_name)) ->
        "false"

      String.starts_with?(module_name, "Mix.Tasks.") ->
        task_name =
          module_name
          |> String.replace("Mix.Tasks.", "")
          |> Macro.underscore()
          |> String.replace("/", ".")

        shortdoc =
          case Regex.run(~r/@shortdoc\s+"([^"]+)"/, source) do
            [_, doc] -> doc
            _ -> nil
          end

        if shortdoc,
          do: "Mix task `mix #{task_name}` — #{shortdoc}",
          else: "Mix task `mix #{task_name}`."

      String.contains?(module_name, ".Live.") or String.ends_with?(module_name, "Live") ->
        page = module_name |> String.split(".") |> List.last() |> String.replace("Live", "")
        "LiveView for the #{humanize(page)} page."

      String.contains?(module_name, ".Components.") ->
        component = module_name |> String.split(".") |> List.last()
        "#{humanize(component)} component."

      String.contains?(module_name, "Controller") ->
        controller =
          module_name |> String.split(".") |> List.last() |> String.replace("Controller", "")
        "Controller for #{humanize(controller)} routes."

      source =~ "use Ash.Domain" ->
        domain = module_name |> String.split(".") |> List.last()
        "#{humanize(domain)} domain — Ash resource registry."

      source =~ "use Ash.Resource" ->
        resource = module_name |> String.split(".") |> List.last()
        "#{humanize(resource)} resource."

      source =~ "use GenServer" ->
        name = module_name |> String.split(".") |> List.last()
        "#{humanize(name)} GenServer."

      true ->
        name = module_name |> String.split(".") |> List.last()
        "#{humanize(name)}."
    end
  end

  defp humanize(name) do
    name
    |> Macro.underscore()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  # -- Single-value pipe fix: `x |> func()` → `func(x)` --

  defp fix_single_pipe(igniter, _finding, page_result) do
    with {:ok, source} <- read_source(page_result.source_file) do
      new_source = apply_single_pipe_patches_iteratively(source)

      if new_source != source do
        write_validated_source!(page_result.source_file, new_source)
      end

      {:ok, igniter}
    end
  end

  # Iterate: fix outermost pipes first, re-parse to expose inner pipes, repeat.
  defp apply_single_pipe_patches_iteratively(source, max_passes \\ 10)
  defp apply_single_pipe_patches_iteratively(source, 0), do: source

  defp apply_single_pipe_patches_iteratively(source, passes_remaining) do
    case collect_single_pipe_patches(source) do
      [] -> source
      patches ->
        new_source = Sourceror.patch_string(source, patches)
        apply_single_pipe_patches_iteratively(new_source, passes_remaining - 1)
    end
  end

  defp collect_single_pipe_patches(source) do
    case Sourceror.parse_string(source) do
      {:ok, ast} ->
        pipe_children = collect_pipe_left_children(ast)

        {_, patches} =
          Macro.prewalk(ast, [], fn
            {:|>, _meta, [left, {func, call_meta, args}]} = node, patches ->
              is_left_of_parent_pipe = MapSet.member?(pipe_children, :erlang.phash2(node))
              left_is_pipe = match?({:|>, _, _}, left)

              if not left_is_pipe and not is_left_of_parent_pipe do
                range = Sourceror.get_range(node)

                if range do
                  new_code = Sourceror.to_string({func, call_meta, [left | args || []]})
                  {node, [%{range: range, change: new_code} | patches]}
                else
                  {node, patches}
                end
              else
                {node, patches}
              end

            node, patches ->
              {node, patches}
          end)

        remove_overlapping_patches(patches)

      _ ->
        []
    end
  end

  # When an outer pipe contains an inner pipe, both produce patches with
  # overlapping ranges. Sourceror.patch_string corrupts the output when patches
  # overlap. Keep only the outermost patch (largest range) for each overlap group.
  defp remove_overlapping_patches(patches) do
    Enum.reject(patches, fn patch ->
      Enum.any?(patches, fn other ->
        other != patch and range_contains?(other.range, patch.range)
      end)
    end)
  end

  defp range_contains?(outer, inner) do
    {os, oc} = {outer.start[:line], outer.start[:column]}
    {oe, oec} = {outer.end[:line], outer.end[:column]}
    {is_, ic} = {inner.start[:line], inner.start[:column]}
    {ie, iec} = {inner.end[:line], inner.end[:column]}

    (os < is_ or (os == is_ and oc <= ic)) and
      (oe > ie or (oe == ie and oec >= iec))
  end

  defp collect_pipe_left_children(ast) do
    {_, children} =
      Macro.prewalk(ast, MapSet.new(), fn
        {:|>, _meta, [left, _right]} = node, acc ->
          {node, MapSet.put(acc, :erlang.phash2(left))}

        node, acc ->
          {node, acc}
      end)

    children
  end

  # -- Atom safety fix: `String.to_atom(x)` → `String.to_existing_atom(x)` --

  defp fix_runtime_atom(igniter, _finding, page_result) do
    with {:ok, source} <- read_source(page_result.source_file) do
      patches = collect_atom_patches(source)

      if patches != [] do
        new_source = Sourceror.patch_string(source, patches)
        write_validated_source!(page_result.source_file, new_source)
      end

      {:ok, igniter}
    end
  end

  defp collect_atom_patches(source) do
    case Sourceror.parse_string(source) do
      {:ok, ast} ->
        {_, patches} =
          Macro.prewalk(ast, [], fn
            {{:., dot_meta, [{:__aliases__, alias_meta, [:String]}, :to_atom]}, call_meta, args} =
                node,
            patches ->
              range = Sourceror.get_range(node)

              if range do
                new_node =
                  {{:., dot_meta, [{:__aliases__, alias_meta, [:String]}, :to_existing_atom]},
                   call_meta, args}

                {node, [%{range: range, change: Sourceror.to_string(new_node)} | patches]}
              else
                {node, patches}
              end

            node, patches ->
              {node, patches}
          end)

        patches

      _ ->
        []
    end
  end


  # -- Maestro rule fix strategies --

  defp add_callback(igniter, module_name, target, template) do
    {func_name, arity} = parse_func_ref(target)

    Igniter.Project.Module.find_and_update_module(igniter, module_name, fn zipper ->
      case Function.move_to_def(zipper, func_name, arity) do
        {:ok, _} -> {:ok, zipper}
        :error -> {:ok, Common.add_code(zipper, template, placement: :after)}
      end
    end)
  end

  defp add_to_mount(igniter, module_name, template) do
    Igniter.Project.Module.find_and_update_module(igniter, module_name, fn zipper ->
      case Function.move_to_def(zipper, :mount, 3) do
        {:ok, zipper} ->
          case Common.move_to_do_block(zipper) do
            {:ok, zipper} ->
              {:ok, Common.add_code(zipper, template, placement: :before)}

            _ ->
              {:ok, zipper}
          end

        :error ->
          {:ok, zipper}
      end
    end)
  end

  # -- Helpers --

  defp parse_func_ref(target) when is_binary(target) do
    case String.split(target, "/") do
      [name, arity] -> {String.to_existing_atom(name), String.to_integer(arity)}
      [name] -> {String.to_existing_atom(name), :any}
    end
  end

  defp parse_func_ref(_), do: {:unknown, :any}
end
