defmodule Mix.Tasks.Maestro.Lint do
  @moduledoc """
  Lint Elixir and HEEx source files for common anti-patterns.

  Checks are driven by rules marked as `linter` in the Maestro Rules system.
  Rules must have a `lint_pattern` to be used as checks.

  ## Usage

      # Lint lib/ in the current project
      mix maestro.lint

      # Lint a specific directory
      mix maestro.lint path/to/dir

      # Lint a specific project by path
      mix maestro.lint --project /path/to/project

      # List active lint checks without running them
      mix maestro.lint --list
  """

  use Mix.Task
  @shortdoc "Check source files for deprecated patterns and anti-patterns"

  def run(args) do
    Mix.Task.run("app.start")

    {opts, rest, _} =
      OptionParser.parse(args, strict: [project: :string, list: :boolean])

    checks = load_checks()

    if opts[:list] do
      list_checks(checks)
    else
      dir =
        case {opts[:project], rest} do
          {project, _} when is_binary(project) -> Path.join(project, "lib")
          {_, [path | _]} -> path
          _ -> "lib"
        end

      dir = Path.expand(dir)

      unless File.dir?(dir) do
        Mix.shell().error("Directory not found: #{dir}")
        exit({:shutdown, 1})
      end

      Mix.shell().info("Linting #{dir} (#{length(checks)} checks from DB)...")

      violations =
        dir
        |> collect_files()
        |> Enum.reject(&String.ends_with?(&1, "maestro/lint.ex"))
        |> Enum.flat_map(&check_file(&1, checks))
        |> Enum.sort_by(fn v -> {v.file, v.line} end)

      if violations == [] do
        Mix.shell().info("No violations found.")
      else
        for v <- violations do
          Mix.shell().info("#{v.file}:#{v.line} [#{v.check_id}] #{v.message}")
        end

        Mix.shell().info("\n#{length(violations)} violation(s) found.")
        exit({:shutdown, 1})
      end
    end
  end

  defp load_checks do
    Maestro.Ops.Rule.linter!()
    |> Enum.map(fn rule ->
      %{
        id: rule_id(rule),
        pattern: Regex.compile!(rule.lint_pattern),
        file_types: Enum.map(rule.lint_file_types, &String.to_atom/1),
        message: rule.lint_message,
        exclude_paths: rule.lint_exclude_paths || [],
        only_paths: rule.lint_only_paths || [],
        category: rule.category,
        rule_id: rule.id
      }
    end)
  end

  defp rule_id(rule) do
    # Build a readable check ID from category + first meaningful words
    base =
      (rule.lint_message || "")
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9\s]/, "")
      |> String.split()
      |> Enum.take(4)
      |> Enum.join("_")

    :"#{rule.category}_#{base}"
  end

  defp list_checks(checks) do
    Mix.shell().info("#{length(checks)} active lint checks:\n")

    for check <- Enum.sort_by(checks, & &1.category) do
      types = Enum.join(check.file_types, ",")
      Mix.shell().info("  [#{check.category}] #{types} — #{check.message}")
    end
  end

  defp collect_files(dir) do
    Path.wildcard(Path.join(dir, "**/*.{ex,heex}"))
  end

  defp check_file(path, checks) do
    file_type = file_type(path)
    content = File.read!(path)
    lines = String.split(content, "\n")
    rel_path = Path.relative_to_cwd(path)

    applicable_checks =
      Enum.filter(checks, fn check ->
        file_type in check.file_types and
          not path_excluded?(rel_path, check.exclude_paths) and
          path_included?(rel_path, check.only_paths)
      end)

    lines
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_num} ->
      for check <- applicable_checks,
          Regex.match?(check.pattern, line) do
        %{
          file: rel_path,
          line: line_num,
          check_id: check.id,
          message: check.message
        }
      end
    end)
  end

  defp path_excluded?(path, excludes) do
    Enum.any?(excludes, &String.contains?(path, &1))
  end

  defp path_included?(_path, []), do: true

  defp path_included?(path, includes) do
    Enum.any?(includes, &String.contains?(path, &1))
  end

  defp file_type(path) do
    cond do
      String.ends_with?(path, ".html.heex") -> :heex
      String.ends_with?(path, ".heex") -> :heex
      String.ends_with?(path, ".ex") -> :ex
      true -> :unknown
    end
  end
end
