defmodule Mix.Tasks.Maestro.Rules.Ingest do
  @moduledoc """
  Ingest rules from deps' usage-rules files and AGENTS.md into Maestro.

  Scans all deps for:
  - `usage-rules.md` (single file)
  - `usage-rules/*.md` (sub-rules directory)
  - `AGENTS.md` (Phoenix auth template, etc.)

  Each top-level bullet point becomes a proposed rule with provenance
  tracking the source dep and file.

  ## Usage

      # Preview what would be ingested
      mix maestro.rules.ingest

      # Actually ingest (creates proposed rules)
      mix maestro.rules.ingest --write

      # Only ingest from specific deps
      mix maestro.rules.ingest --write --deps ash,phoenix

      # Show versions of all deps with rules
      mix maestro.rules.ingest --versions
  """

  use Mix.Task
  @shortdoc "Ingest rules from deps usage-rules into Maestro"

  @deps_path "deps"

  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        strict: [write: :boolean, deps: :string, versions: :boolean]
      )

    if opts[:versions] do
      show_versions()
    else
      write = opts[:write] || false
      dep_filter = if opts[:deps], do: String.split(opts[:deps], ","), else: nil
      ingest(write, dep_filter)
    end
  end

  defp show_versions do
    find_all_rule_sources()
    |> Enum.group_by(fn {dep, _, _} -> dep end)
    |> Enum.sort_by(fn {dep, _} -> dep end)
    |> Enum.each(fn {dep, files} ->
      version = get_dep_version(dep)
      file_count = length(files)
      Mix.shell().info("  #{dep} v#{version || "?"} — #{file_count} file(s)")
    end)
  end

  defp ingest(write, dep_filter) do
    sources = find_all_rule_sources()
    sources = if dep_filter, do: Enum.filter(sources, fn {dep, _, _} -> dep in dep_filter end), else: sources

    existing_contents =
      Maestro.Ops.Rule.read!()
      |> MapSet.new(fn r -> String.trim(r.content) end)

    rules =
      sources
      |> Enum.flat_map(fn {dep, file, category} ->
        parse_rules_from_file(dep, file, category)
      end)
      |> Enum.reject(fn attrs ->
        MapSet.member?(existing_contents, String.trim(attrs.content))
      end)

    Mix.shell().info("Found #{length(rules)} new rules from #{length(sources)} files\n")

    rules
    |> Enum.group_by(fn r -> r.source_project_slug end)
    |> Enum.sort_by(fn {dep, _} -> dep end)
    |> Enum.each(fn {dep, dep_rules} ->
      Mix.shell().info("  #{dep}: #{length(dep_rules)} rules")
    end)

    if write and rules != [] do
      Mix.shell().info("\nIngesting #{length(rules)} rules...")

      Enum.each(rules, fn attrs ->
        case Maestro.Ops.Rule.propose(attrs) do
          {:ok, _} -> :ok
          {:error, err} -> Mix.shell().error("  Failed: #{inspect(err)}")
        end
      end)

      Mix.shell().info("Done. Review at http://localhost:4004/rules")
    else
      if rules == [] do
        Mix.shell().info("\nNo new rules to ingest (all already exist)")
      else
        Mix.shell().info("\nPass --write to ingest these rules")
      end
    end
  end

  defp find_all_rule_sources do
    deps_dir = Path.expand(@deps_path)

    # Find usage-rules.md files
    single_files =
      Path.wildcard(Path.join(deps_dir, "*/usage-rules.md"))
      |> Enum.map(fn path ->
        dep = path |> Path.dirname() |> Path.basename()
        {dep, path, categorize_dep(dep)}
      end)

    # Find usage-rules/*.md directories
    dir_files =
      Path.wildcard(Path.join(deps_dir, "*/usage-rules/*.md"))
      |> Enum.map(fn path ->
        dep = path |> Path.dirname() |> Path.dirname() |> Path.basename()
        sub = path |> Path.basename(".md")
        {dep, path, categorize_sub(dep, sub)}
      end)

    # Find AGENTS.md files
    agents_files =
      Path.wildcard(Path.join(deps_dir, "**/AGENTS.md"))
      |> Enum.reject(&String.contains?(&1, "sentry"))
      |> Enum.map(fn path ->
        # Walk up to find the dep name
        dep = extract_dep_name(path, deps_dir)
        {dep, path, categorize_dep(dep)}
      end)

    (single_files ++ dir_files ++ agents_files)
    |> Enum.uniq_by(fn {_, path, _} -> path end)
    |> Enum.sort()
  end

  defp parse_rules_from_file(dep, file_path, category) do
    content = File.read!(file_path)
    sub_file = Path.basename(file_path, ".md")
    version = get_dep_version(dep)

    # Extract top-level bullet points (lines starting with "- ")
    # Include continuation lines (indented or code blocks) as part of the rule
    content
    |> String.split("\n")
    |> chunk_rules()
    |> Enum.map(fn rule_text ->
      rule_text = String.trim(rule_text)

      # Skip very short rules (headers, empty)
      if String.length(rule_text) > 20 do
        %{
          content: rule_text,
          category: category,
          severity: detect_severity(rule_text),
          source_project_slug: dep,
          source_commit: "v#{version || "unknown"}",
          source_context: "From #{dep} #{sub_file}.md (auto-ingested)",
          applies_to: applies_to_for_dep(dep),
          tags: [dep, sub_file] |> Enum.uniq()
        }
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp chunk_rules(lines) do
    {chunks, current} =
      Enum.reduce(lines, {[], nil}, fn line, {chunks, current} ->
        cond do
          # New top-level rule
          Regex.match?(~r/^- /, line) ->
            chunks = if current, do: [current | chunks], else: chunks
            {chunks, line}

          # Continuation of current rule (indented, code block, or empty line within)
          current != nil and (String.starts_with?(line, "  ") or String.starts_with?(line, "\t") or line == "" or String.starts_with?(line, "    ")) ->
            {chunks, current <> "\n" <> line}

          # Something else (header, etc) — end current chunk
          true ->
            chunks = if current, do: [current | chunks], else: chunks
            {chunks, nil}
        end
      end)

    chunks = if current, do: [current | chunks], else: chunks
    Enum.reverse(chunks)
  end

  defp detect_severity(text) do
    cond do
      String.contains?(text, "**Always**") or String.contains?(text, "**ALWAYS**") or
        String.contains?(text, "**Never**") or String.contains?(text, "**NEVER**") or
        String.contains?(text, "FORBIDDEN") or String.contains?(text, "**must**") ->
        :must

      String.contains?(text, "**Avoid**") or String.contains?(text, "should") ->
        :should

      true ->
        :should
    end
  end

  defp categorize_dep("ash"), do: :ash
  defp categorize_dep("ash_phoenix"), do: :ash
  defp categorize_dep("ash_postgres"), do: :ash
  defp categorize_dep("ash_authentication"), do: :ash
  defp categorize_dep("ash_oban"), do: :ash
  defp categorize_dep("ash_ai"), do: :ash
  defp categorize_dep("ash_json_api"), do: :ash
  defp categorize_dep("phoenix"), do: :liveview
  defp categorize_dep("igniter"), do: :elixir
  defp categorize_dep("spark"), do: :ash
  defp categorize_dep("reactor"), do: :ash
  defp categorize_dep("cinder"), do: :components
  defp categorize_dep("usage_rules"), do: :elixir
  defp categorize_dep(_), do: :elixir

  defp categorize_sub(_dep, "liveview"), do: :liveview
  defp categorize_sub(_dep, "html"), do: :heex
  defp categorize_sub(_dep, "ecto"), do: :ash
  defp categorize_sub(_dep, "phoenix"), do: :routing
  defp categorize_sub(_dep, "elixir"), do: :elixir
  defp categorize_sub(_dep, "otp"), do: :elixir
  defp categorize_sub(_dep, "actions"), do: :ash
  defp categorize_sub(_dep, "migrations"), do: :ash
  defp categorize_sub(_dep, "testing"), do: :testing
  defp categorize_sub(_dep, "authorization"), do: :security
  defp categorize_sub(dep, _), do: categorize_dep(dep)

  defp applies_to_for_dep("ash"), do: ["ash"]
  defp applies_to_for_dep("ash_" <> _), do: ["ash"]
  defp applies_to_for_dep("phoenix"), do: ["phoenix"]
  defp applies_to_for_dep("spark"), do: ["ash"]
  defp applies_to_for_dep("reactor"), do: ["ash"]
  defp applies_to_for_dep("cinder"), do: ["ash", "liveview"]
  defp applies_to_for_dep(_), do: ["all"]

  defp extract_dep_name(path, deps_dir) do
    path
    |> String.replace_prefix(deps_dir <> "/", "")
    |> String.split("/")
    |> List.first()
  end

  defp get_dep_version(dep) do
    mix_exs = Path.join([@deps_path, dep, "mix.exs"])
    if File.exists?(mix_exs) do
      case Regex.run(~r/@version\s+"([^"]+)"/, File.read!(mix_exs)) do
        [_, version] -> version
        _ ->
          case Regex.run(~r/version:\s+"([^"]+)"/, File.read!(mix_exs)) do
            [_, version] -> version
            _ -> nil
          end
      end
    end
  end
end
