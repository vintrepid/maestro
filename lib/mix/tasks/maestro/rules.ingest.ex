defmodule Mix.Tasks.Maestro.Rules.Ingest do
  @moduledoc """
  Ingest rules from deps' usage-rules files into Maestro.

  Reads usage-rules.md and usage-rules/*.md directly from deps/,
  parses bullet points as rule candidates, filters out noise,
  deduplicates against existing rules, and creates proposed rules.

  ## Usage

      # Preview what would be ingested
      mix maestro.rules.ingest

      # Actually create proposed rules
      mix maestro.rules.ingest --write

      # Only specific deps
      mix maestro.rules.ingest --write --deps ash,phoenix

      # Show what deps have usage rules
      mix maestro.rules.ingest --list
  """

  use Mix.Task
  @shortdoc "Ingest rules from deps usage-rules into Maestro"

  @deps_path "deps"
  @min_rule_length 30

  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        strict: [write: :boolean, deps: :string, list: :boolean]
      )

    if opts[:list] do
      list_deps()
    else
      ingest(opts)
    end
  end

  defp list_deps do
    find_all_rule_sources()
    |> Enum.group_by(fn {dep, _, _} -> dep end)
    |> Enum.sort_by(fn {dep, _} -> dep end)
    |> Enum.each(fn {dep, files} ->
      version = get_dep_version(dep)
      names = Enum.map(files, fn {_, path, _} -> Path.basename(path, ".md") end) |> Enum.join(", ")
      Mix.shell().info("  #{dep} v#{version || "?"} — #{length(files)} file(s): #{names}")
    end)
  end

  defp ingest(opts) do
    write = opts[:write] || false
    dep_filter = if opts[:deps], do: String.split(opts[:deps], ","), else: nil

    sources = find_all_rule_sources()
    sources = if dep_filter, do: Enum.filter(sources, fn {dep, _, _} -> dep in dep_filter end), else: sources

    Mix.shell().info("Scanning #{length(sources)} files from #{sources |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> length()} deps...")

    # Parse all rules from source files
    candidates = Enum.flat_map(sources, fn {dep, file, category} ->
      parse_rules_from_file(dep, file, category)
    end)

    Mix.shell().info("Found #{length(candidates)} rule candidates")

    # Dedup against existing rules
    existing = Maestro.Ops.Rule.read!()
    existing_contents = MapSet.new(existing, &normalize(&1.content))

    new_rules = Enum.reject(candidates, fn attrs ->
      MapSet.member?(existing_contents, normalize(attrs.content))
    end)

    Mix.shell().info("#{length(new_rules)} new rules (#{length(candidates) - length(new_rules)} already exist)\n")

    # Summary by source
    new_rules
    |> Enum.group_by(& &1.source_project_slug)
    |> Enum.sort_by(fn {dep, _} -> dep end)
    |> Enum.each(fn {dep, dep_rules} ->
      Mix.shell().info("  #{dep}: #{length(dep_rules)} new")
    end)

    if write and new_rules != [] do
      Mix.shell().info("\nIngesting #{length(new_rules)} rules...")

      ok =
        Enum.count(new_rules, fn attrs ->
          case Maestro.Ops.Rule.propose(attrs) do
            {:ok, _} -> true
            {:error, err} ->
              Mix.shell().error("  Failed: #{inspect(err)}")
              false
          end
        end)

      Mix.shell().info("Created #{ok} proposed rules. Review at http://localhost:4004/rules")
    else
      if new_rules == [] do
        Mix.shell().info("\nAll rules already ingested.")
      else
        Mix.shell().info("\nPass --write to ingest")
      end
    end
  end

  # --- File Discovery ---

  defp find_all_rule_sources do
    deps_dir = Path.expand(@deps_path)

    single_files =
      Path.wildcard(Path.join(deps_dir, "*/usage-rules.md"))
      |> Enum.map(fn path ->
        dep = path |> Path.dirname() |> Path.basename()
        {dep, path, categorize(dep, nil)}
      end)

    sub_files =
      Path.wildcard(Path.join(deps_dir, "*/usage-rules/*.md"))
      |> Enum.map(fn path ->
        dep = path |> Path.dirname() |> Path.dirname() |> Path.basename()
        sub = path |> Path.basename(".md")
        {dep, path, categorize(dep, sub)}
      end)

    (single_files ++ sub_files)
    |> Enum.uniq_by(fn {_, path, _} -> path end)
    |> Enum.sort()
  end

  # --- Parsing ---

  defp parse_rules_from_file(dep, file_path, category) do
    content = File.read!(file_path)
    sub = Path.basename(file_path, ".md")
    version = get_dep_version(dep)

    content
    |> String.split("\n")
    |> chunk_rules()
    |> Enum.filter(&(String.length(String.trim(&1)) >= @min_rule_length))
    |> Enum.map(fn rule_text ->
      rule_text = String.trim(rule_text)

      %{
        content: rule_text,
        category: category,
        severity: detect_severity(rule_text),
        source_project_slug: dep,
        source_commit: if(version, do: "v#{version}", else: nil),
        source_context: "#{dep}:#{sub}",
        applies_to: applies_to(dep),
        tags: [dep, sub] |> Enum.uniq()
      }
    end)
  end

  defp chunk_rules(lines) do
    {chunks, current} =
      Enum.reduce(lines, {[], nil}, fn line, {chunks, current} ->
        cond do
          # Skip headers and HTML comments
          String.starts_with?(line, "#") or String.starts_with?(line, "<!--") ->
            chunks = if current, do: [current | chunks], else: chunks
            {chunks, nil}

          # New top-level bullet
          Regex.match?(~r/^- /, line) ->
            chunks = if current, do: [current | chunks], else: chunks
            {chunks, line}

          # Continuation
          current != nil and (line == "" or String.starts_with?(line, "  ") or
            String.starts_with?(line, "\t") or String.starts_with?(line, "```")) ->
            {chunks, current <> "\n" <> line}

          true ->
            chunks = if current, do: [current | chunks], else: chunks
            {chunks, nil}
        end
      end)

    chunks = if current, do: [current | chunks], else: chunks
    Enum.reverse(chunks)
  end

  # --- Classification ---

  defp detect_severity(text) do
    cond do
      Regex.match?(~r/\*\*(Always|ALWAYS|Never|NEVER|must|MUST|FORBIDDEN)\*\*/i, text) -> :must
      Regex.match?(~r/\*\*Avoid\*\*/i, text) -> :should
      true -> :should
    end
  end

  defp categorize("ash", nil), do: :ash
  defp categorize("ash", "testing"), do: :testing
  defp categorize("ash", "authorization"), do: :security
  defp categorize("ash", _sub), do: :ash
  defp categorize("ash_phoenix", _), do: :ash
  defp categorize("ash_postgres", _), do: :ash
  defp categorize("ash_authentication", _), do: :security
  defp categorize("ash_oban", _), do: :ash
  defp categorize("ash_ai", _), do: :ash
  defp categorize("phoenix", "liveview"), do: :liveview
  defp categorize("phoenix", "html"), do: :heex
  defp categorize("phoenix", "ecto"), do: :ash
  defp categorize("phoenix", "phoenix"), do: :routing
  defp categorize("phoenix", "elixir"), do: :elixir
  defp categorize("phoenix", _), do: :liveview
  defp categorize("igniter", _), do: :elixir
  defp categorize("usage_rules", "elixir"), do: :elixir
  defp categorize("usage_rules", "otp"), do: :elixir
  defp categorize("usage_rules", _), do: :elixir
  defp categorize(_, _), do: :elixir

  defp applies_to("ash"), do: ["ash"]
  defp applies_to("ash_" <> _), do: ["ash"]
  defp applies_to("phoenix"), do: ["phoenix"]
  defp applies_to(_), do: ["all"]

  defp normalize(content) do
    content |> String.trim() |> String.replace(~r/\s+/, " ") |> String.downcase()
  end

  defp get_dep_version(dep) do
    mix_exs = Path.join([@deps_path, dep, "mix.exs"])
    if File.exists?(mix_exs) do
      content = File.read!(mix_exs)
      case Regex.run(~r/@version\s+"([^"]+)"/, content) do
        [_, v] -> v
        _ ->
          case Regex.run(~r/version:\s+"([^"]+)"/, content) do
            [_, v] -> v
            _ -> nil
          end
      end
    end
  end
end
