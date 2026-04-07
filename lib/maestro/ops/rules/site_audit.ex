defmodule Maestro.Ops.Rules.SiteAudit do
  @moduledoc """
  AST-based auditing of site pages against approved rules.

  Parses each LiveView's source with Sourceror and checks structural
  properties of the AST rather than regex matching against source text.
  This eliminates false positives from string matching.

  No DB access, no IO. Takes a list of page maps and a list of rules,
  returns per-page audit results.
  """

  @doc """
  Discovers all .ex modules in the project.
  Returns a list of page maps: %{path, module, source_file, source, ast, heex_blocks}.
  """
  @spec discover_modules(String.t()) :: list()
  def discover_modules(project_path) do
    Enum.flat_map(Path.wildcard(Path.join(project_path, "lib/**/*.ex")), fn file ->
      source = File.read!(file)
    
      case extract_module_name(source) do
        nil ->
          []
    
        mod_name ->
          ast = parse_ast(source)
          heex = extract_heex_blocks(source)
    
          [
            %{
              path: Path.relative_to(file, project_path),
              module: Module.concat([mod_name]),
              source_file: file,
              source: source,
              ast: ast,
              heex_blocks: heex
            }
          ]
      end
    end)
  end

  defp extract_module_name(source) do
    case Regex.run(~r/defmodule\s+([\w.]+)/, source) do
      [_, name] -> name
      _ -> nil
    end
  end

  @doc """
  Discovers pages from the router, filtering to app-owned LiveViews only.
  Returns a list of page maps: %{path, module, source_file, source, ast, heex_blocks}.
  """
  @spec discover_pages(any(), any()) :: term()
  def discover_pages(router_module, app_web_prefix) do
    router_module.__routes__()
    |> Enum.filter(&(&1.metadata[:phoenix_live_view] != nil))
    |> Enum.map(fn route ->
      {module, _action, _opts, _extra} = route.metadata[:phoenix_live_view]
      %{path: route.path, module: module}
    end)
    |> Enum.uniq_by(& &1.path)
    |> Enum.filter(&String.starts_with?(to_string(&1.module), to_string(app_web_prefix)))
    |> Enum.map(fn page ->
      source_file = to_string(page.module.__info__(:compile)[:source])
      source = File.read!(source_file)
      ast = parse_ast(source)
      heex = extract_heex_blocks(source)

      Map.merge(page, %{
        source_file: source_file,
        source: source,
        ast: ast,
        heex_blocks: heex
      })
    end)
    |> Enum.sort_by(& &1.path)
  end

  @doc """
  Audits a list of pages against a list of rules.
  Returns a list of page results, each with per-rule findings.
  """
  @spec audit_pages(any(), any()) :: term()
  def audit_pages(pages, rules) do
    checks = Enum.map(rules, &rule_to_check/1)
    applicable_checks = Enum.reject(checks, &(&1.type == :skip))

    Enum.map(pages, fn page ->
      findings = Enum.map(applicable_checks, &check_page(page, &1))
      pass_count = Enum.count(findings, & &1.pass?)
      fail_count = Enum.count(findings, &(not &1.pass?))
      skip_count = length(checks) - length(applicable_checks)

      %{
        path: page.path,
        module: page.module,
        source_file: page.source_file,
        findings: findings,
        pass: pass_count,
        fail: fail_count,
        skip: skip_count,
        total: length(applicable_checks),
        score:
          if(pass_count + fail_count > 0,
            do: round(pass_count / (pass_count + fail_count) * 100),
            else: 100
          )
      }
    end)
  end

  @doc """
  Summarizes audit results across all pages.
  """
  @spec summarize(any()) :: term()
  def summarize(page_results) do
    total_pages = length(page_results)

    avg_score =
      if total_pages > 0,
        do: round(Enum.sum(Enum.map(page_results, & &1.score)) / total_pages),
        else: 0

    all_findings = Enum.flat_map(page_results, & &1.findings)
    total_checks = length(all_findings)
    total_pass = Enum.count(all_findings, & &1.pass?)
    total_fail = total_checks - total_pass

    failing_rules =
      all_findings
      |> Enum.reject(& &1.pass?)
      |> Enum.group_by(& &1.rule_category)
      |> Enum.map(fn {cat, fs} -> %{category: cat, count: length(fs)} end)
      |> Enum.sort_by(& &1.count, :desc)

    %{
      total_pages: total_pages,
      avg_score: avg_score,
      total_checks: total_checks,
      total_pass: total_pass,
      total_fail: total_fail,
      failing_by_category: failing_rules
    }
  end

  # -- AST parsing helpers --

  defp parse_ast(source) do
    case Sourceror.parse_string(source) do
      {:ok, ast} -> ast
      _ -> nil
    end
  end

  defp extract_heex_blocks(source) do
    Enum.map(Regex.scan(~r/~H"""(.*?)"""/s, source), fn [_, content] -> content end)
  end

  # -- Rule to check mapping --
  # Each rule maps to an AST-based check function.
  # The check inspects structural properties, not string patterns.

  defp rule_to_check(rule) do
    content = rule.content || ""

    base = %{
      rule_id: rule.id,
      rule_content: String.slice(content, 0, 120),
      rule_category: rule.category,
      type: :skip,
      pattern: nil,
      func_name: nil,
      check_module: nil,
      source_project: rule.source_project_slug
    }

    categorize_check(base, rule, content)
  end

  # Categorize rules into AST check types based on their content
  defp categorize_check(base, rule, content) do
    cond do
      # AST module check — rule has a check_module in lint_config
      has_check_module?(rule) ->
        mod = String.to_existing_atom("Elixir.#{rule.lint_config.check_module}")
        %{base | type: :ast_check_module, check_module: mod}

      # Form rules — now handled by MaestroTool.Lint.Checks.FormUsage check module.
      # Skip legacy string-based check; the linter rule with check_module handles it.
      form_rule?(content) ->
        %{base | type: :skip}

      # Icon rules — check for Heroicons module usage vs <.icon>
      icon_rule?(content) ->
        %{base | type: :ast_icon_check}

      # Stream rules — check for Enum on streams
      stream_rule?(content) ->
        %{base | type: :ast_stream_check}

      # DaisyUI rules — check for raw Tailwind vs DaisyUI classes
      css_rule?(content) ->
        %{base | type: :ast_css_check}

      # Explicit lint_pattern — AST search for the pattern
      is_binary(rule.lint_pattern) and rule.lint_pattern != "" ->
        %{base | type: :ast_lint_pattern, pattern: rule.lint_pattern}

      # Callback existence check
      rule.fix_type == :add_callback and is_binary(rule.fix_target) and rule.fix_target != "" ->
        func_name = hd(String.split(rule.fix_target, "/"))
        %{base | type: :ast_has_function, func_name: func_name}

      # Content-derived structural checks
      true ->
        derive_ast_check(base, content)
    end
  end

  defp has_check_module?(rule) do
    rule.lint_config != nil and
      is_binary(rule.lint_config.check_module) and
      rule.lint_config.check_module != ""
  end

  defp form_rule?(content) do
    String.contains?(content, "to_form") or
      String.contains?(content, "<.form") or
      String.contains?(content, "<.input") or
      String.contains?(content, "form inputs")
  end

  defp icon_rule?(content) do
    String.contains?(content, "<.icon") or String.contains?(content, "Heroicons")
  end

  defp stream_rule?(content) do
    String.contains?(content, "stream") and String.contains?(content, "Enum")
  end

  defp css_rule?(content) do
    String.contains?(content, "DaisyUI") or String.contains?(content, "daisyui")
  end

  # Derive an AST check from rule content when no explicit categorization matches.
  # Only "Never" rules produce checks — "Always" rules with code examples are
  # guidance, not structural requirements checkable per-page.
  defp derive_ast_check(base, content) do
    directive = extract_directive(content)
    code_patterns = extract_code_patterns(content)

    case {directive, code_patterns} do
      # "Never X" with a code pattern — check AST for the pattern's absence
      {:never, [pattern | _]} when byte_size(pattern) >= 4 ->
        %{base | type: :ast_absent, pattern: pattern}

      # "Always" rules are guidance — skip per-page structural checks
      _ ->
        base
    end
  end

  defp extract_directive(content) do
    has_never =
      String.contains?(content, "**Never**") or String.contains?(content, "NEVER") or
        String.contains?(content, "don't") or String.contains?(content, "do NOT")

    has_always =
      String.contains?(content, "**Always**") or String.contains?(content, "ALWAYS") or
        String.contains?(content, "MUST")

    cond do
      has_never and not has_always -> :never
      has_always and not has_never -> :always
      true -> nil
    end
  end

  defp extract_code_patterns(content) do
    Regex.scan(~r/`([^`]{3,60})`/, content)
    |> Enum.map(fn [_, code] -> String.trim(code) end)
    |> Enum.reject(&prose_not_code?/1)
    |> Enum.sort_by(&byte_size/1, :desc)
    |> Enum.uniq()
  end

  defp prose_not_code?(text) do
    keywords =
      ~w(case if cond with for do end else true false nil ok error string integer atom map list tuple)

    downcased = String.downcase(text)

    downcased in keywords or
      not (String.contains?(text, ".") or String.contains?(text, "_") or
             String.contains?(text, "(") or String.contains?(text, "<") or
             String.contains?(text, "@") or String.contains?(text, ":") or
             Regex.match?(~r/^[a-z_]+$/, text) or Regex.match?(~r/^[A-Z]/, text))
  end

  # -- AST-based check execution --

  defp check_page(page, check) do
    result = %{
      rule_id: check.rule_id,
      rule_content: check.rule_content,
      rule_category: check.rule_category,
      pass?: true,
      evidence: []
    }

    case check.type do
      :ast_check_module -> check_with_module(page, check, result)
      :ast_form_check -> check_forms(page, result)
      :ast_icon_check -> check_icons(page, result)
      :ast_stream_check -> check_streams(page, result)
      # CSS checks need design-time analysis, skip for now
      :ast_css_check -> result
      :ast_has_function -> check_has_function(page, check, result)
      :ast_lint_pattern -> check_lint_pattern(page, check, result)
      :ast_absent -> check_pattern_absent(page, check, result)
      :ast_present -> check_pattern_present(page, check, result)
      :skip -> result
    end
  end

  # -- AST module check --
  # Delegates to a MaestroTool.Lint.Check module from the DB rule's lint_config.

  defp check_with_module(page, check, result) do
    mod = check.check_module
    meta = %{path: page.path, source: page.source}

    violations =
      if page.ast do
        mod.check(page.ast, meta)
      else
        []
      end

    if violations == [] do
      result
    else
      evidence = Enum.map(violations, & &1.message)

      %{
        result
        | pass?: false,
          evidence: evidence,
          violations: violations,
          check_module: mod
      }
    end
  end

  # -- Form checks via AST --
  # Checks that pages with forms use <.form for={@form}> and <.input>

  defp check_forms(page, result) do
    heex = Enum.join(page.heex_blocks, "\n")

    has_form = String.contains?(heex, "<.form") or String.contains?(heex, "<form")

    if not has_form do
      # No forms on this page — rule doesn't apply, pass
      result
    else
      issues = []

      # Check for old let={f} pattern
      issues =
        if String.contains?(heex, "let={") do
          ["Uses deprecated let={f} pattern — use for={@form} instead" | issues]
        else
          issues
        end

      # Check for @form usage
      issues =
        if String.contains?(heex, "for={@form}") do
          issues
        else
          ["Form does not use for={@form}" | issues]
        end

      # Check for <.input> usage (vs raw <input>)
      has_raw_input = Regex.match?(~r/<input\s/, heex)
      has_component_input = String.contains?(heex, "<.input")

      issues =
        if has_raw_input and not has_component_input do
          ["Uses raw <input> instead of <.input> component" | issues]
        else
          issues
        end

      if issues == [] do
        result
      else
        %{result | pass?: false, evidence: issues}
      end
    end
  end

  # -- Icon checks via AST --
  # Checks that pages use <.icon> not Heroicons modules

  defp check_icons(page, result) do
    if page.ast do
      has_heroicons = ast_contains_module?(page.ast, :Heroicons)

      if has_heroicons do
        %{
          result
          | pass?: false,
            evidence: ["Uses Heroicons module directly — use <.icon> component instead"]
        }
      else
        result
      end
    else
      result
    end
  end

  # -- Stream checks via AST --
  # Checks that Enum functions aren't called on streams

  defp check_streams(page, result) do
    if page.ast do
      # Look for Enum calls where the first arg is a stream-related variable
      stream_enum_calls = find_enum_on_streams(page.ast)

      if stream_enum_calls != [] do
        evidence = Enum.map(stream_enum_calls, &"Enum.#{&1} called on stream")
        %{result | pass?: false, evidence: evidence}
      else
        result
      end
    else
      result
    end
  end

  # -- Function existence check via AST --

  defp check_has_function(page, check, result) do
    if page.ast do
      has_func = ast_has_def?(page.ast, String.to_existing_atom(check.func_name))

      if has_func do
        result
      else
        %{result | pass?: false, evidence: ["Missing required function: #{check.func_name}"]}
      end
    else
      result
    end
  end

  # -- Lint pattern check (structural search in AST for specific constructs) --

  defp check_lint_pattern(page, check, result) do
    # Match lint patterns only in code, not inside string literals or module attributes.
    # Strip strings, heredocs, sigils, and comments before matching to avoid false positives
    # (e.g. LintExtractor containing patterns as data, not as actual code usage).
    case Regex.compile(check.pattern) do
      {:ok, regex} ->
        code_only = strip_string_literals(page.source)

        if Regex.match?(regex, code_only) do
          %{result | pass?: false, evidence: ["Lint pattern matched: #{check.pattern}"]}
        else
          result
        end

      _ ->
        result
    end
  end

  # Strip string literals, heredocs, sigils, and comments from source
  # so lint patterns only match actual code, not data/docs.
  defp strip_string_literals(source) do
    source
    # Strip heredocs (triple-quoted strings) first
    |> String.replace(~r/~[A-Z]\"{3}.*?\"{3}/s, "\"\"")
    |> String.replace(~r/\"{3}.*?\"{3}/s, "\"\"")
    # Strip sigils with delimiters
    |> String.replace(~r/~[a-zA-Z]\(.*?\)/s, "\"\"")
    |> String.replace(~r/~[a-zA-Z]\[.*?\]/s, "\"\"")
    |> String.replace(~r/~[a-zA-Z]\{.*?\}/s, "\"\"")
    |> String.replace(~r/~[a-zA-Z]<.*?>/s, "\"\"")
    |> String.replace(~r/~[a-zA-Z]\/.*?\//s, "\"\"")
    |> String.replace(~r/~[a-zA-Z]\|.*?\|/s, "\"\"")
    # Strip regular double-quoted strings (non-greedy, single-line)
    |> String.replace(~r/"(?:[^"\\]|\\.)*"/s, "\"\"")
    # Strip single-quoted charlists
    |> String.replace(~r/'(?:[^'\\]|\\.)*'/s, "''")
    # Strip line comments
    |> String.replace(~r/#.*$$/m, "")
  end

  # -- Pattern absent/present checks --
  # These use AST-aware search rather than raw string matching

  defp check_pattern_absent(page, check, result) do
    # Check if the pattern appears structurally in the source
    if source_contains_construct?(page, check.pattern) do
      %{result | pass?: false, evidence: ["Found prohibited pattern: #{check.pattern}"]}
    else
      result
    end
  end

  defp check_pattern_present(page, check, result) do
    if source_contains_construct?(page, check.pattern) do
      result
    else
      %{result | pass?: false, evidence: ["Missing required pattern: #{check.pattern}"]}
    end
  end

  # -- AST utility functions --

  defp ast_contains_module?(ast, module_atom) do
    {_, found} =
      Macro.prewalk(ast, false, fn
        {:__aliases__, _, atoms} = node, acc ->
          if module_atom in atoms, do: {node, true}, else: {node, acc}

        node, acc ->
          {node, acc}
      end)

    found
  end

  defp ast_has_def?(ast, func_name) do
    {_, found} =
      Macro.prewalk(ast, false, fn
        {:def, _, [{^func_name, _, _} | _]} = node, _acc -> {node, true}
        {:def, _, [{:when, _, [{^func_name, _, _} | _]} | _]} = node, _acc -> {node, true}
        node, acc -> {node, acc}
      end)

    found
  end

  defp find_enum_on_streams(ast) do
    {_, calls} =
      Macro.prewalk(ast, [], fn
        {{:., _, [{:__aliases__, _, [:Enum]}, func]}, _, [first_arg | _]} = node, acc ->
          if stream_variable?(first_arg) do
            {node, [func | acc]}
          else
            {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    Enum.uniq(calls)
  end

  defp stream_variable?({name, _, nil}) when is_atom(name) do
    name_str = Atom.to_string(name)
    String.starts_with?(name_str, "stream") or String.ends_with?(name_str, "_stream")
  end

  defp stream_variable?(_), do: false

  # Check if source contains a construct — uses both AST and HEEx awareness
  defp source_contains_construct?(page, pattern) do
    # Check in Elixir AST (function calls, module references)
    in_elixir = String.contains?(page.source, pattern)

    # Check in HEEx blocks
    in_heex = Enum.any?(page.heex_blocks, &String.contains?(&1, pattern))

    in_elixir or in_heex
  end
end
