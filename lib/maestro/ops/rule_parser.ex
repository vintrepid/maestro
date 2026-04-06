defmodule Maestro.Ops.RuleParser do
  @moduledoc """
  Shared rule parsing logic used by both maestro.update and maestro.rules.ingest.
  Handles chunking markdown into rules, categorization, severity detection, and content hashing.
  """

  @min_rule_length 30

  @doc "Parse a usage-rules markdown file into rule attribute maps."
  @spec parse_rules_from_file(String.t(), any(), any()) :: term()
  def parse_rules_from_file(path, dep, sub_rule_name) do
    File.read!(path)
    |> String.split("\n")
    |> chunk_rules()
    |> Enum.filter(&(String.length(String.trim(&1)) >= @min_rule_length))
    |> Enum.map(fn rule_text ->
      rule_text = String.trim(rule_text)

      %{
        content: rule_text,
        content_hash: content_hash(rule_text),
        category: categorize(dep, sub_rule_name),
        severity: detect_severity(rule_text),
        source_type: :library_file,
        source_project_slug: dep,
        source_commit: get_dep_version(dep),
        source_context: "#{dep}:#{sub_rule_name}",
        applies_to: applies_to(dep),
        tags: Enum.uniq([dep, sub_rule_name])
      }
    end)
  end

  @doc "SHA256 hash of normalized content for deduplication."
  @spec content_hash(any()) :: term()
  def content_hash(text) do
    text
    |> normalize()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  @doc "Normalize content for comparison: trim, collapse whitespace, downcase."
  @spec normalize(any()) :: term()
  def normalize(content) do
    content
    |> String.trim()
    |> String.replace(~r/^(\*\*(Always|Never|ALWAYS|NEVER|Must|Avoid)\*\*\s*)+/i, "")
    |> String.replace(~r/^(- )+/, "")
    |> String.replace(~r/\s+/, " ")
    |> String.downcase()
  end

  @doc "SHA256 hash of raw file content (for RuleSource change detection)."
  @spec file_hash(String.t()) :: term()
  def file_hash(path) do
    File.read!(path)
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  @doc "Chunk markdown lines into individual rule strings."
  @spec chunk_rules(any()) :: term()
  def chunk_rules(lines) do
    {chunks, current} =
      Enum.reduce(lines, {[], nil}, fn line, {chunks, current} ->
        cond do
          String.starts_with?(line, "#") or String.starts_with?(line, "<!--") ->
            chunks = if current, do: [current | chunks], else: chunks
            {chunks, nil}

          Regex.match?(~r/^- /, line) ->
            chunks = if current, do: [current | chunks], else: chunks
            {chunks, line}

          current != nil and
              (line == "" or String.starts_with?(line, "  ") or
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

  @doc "Detect severity from rule text."
  @spec detect_severity(any()) :: term()
  def detect_severity(text) do
    cond do
      Regex.match?(~r/\*\*(Always|ALWAYS|Never|NEVER|must|MUST|FORBIDDEN)\*\*/i, text) -> :must
      Regex.match?(~r/\*\*Avoid\*\*/i, text) -> :should
      true -> :should
    end
  end

  @doc "Categorize a rule based on its source dep and sub-rule file."
  @spec categorize(any(), any()) :: term()
  def categorize("ash", "testing"), do: :testing
  @spec categorize(any(), any()) :: term()
  def categorize("ash", "authorization"), do: :security
  @spec categorize(any(), any()) :: term()
  def categorize("ash" <> _, _), do: :ash
  @spec categorize(any(), any()) :: term()
  def categorize("phoenix", "liveview"), do: :liveview
  @spec categorize(any(), any()) :: term()
  def categorize("phoenix", "html"), do: :heex
  @spec categorize(any(), any()) :: term()
  def categorize("phoenix", "ecto"), do: :ash
  @spec categorize(any(), any()) :: term()
  def categorize("phoenix", "phoenix"), do: :routing
  @spec categorize(any(), any()) :: term()
  def categorize("phoenix", "elixir"), do: :elixir
  @spec categorize(any(), any()) :: term()
  def categorize("phoenix", _), do: :liveview
  @spec categorize(any(), any()) :: term()
  def categorize("igniter", _), do: :elixir
  @spec categorize(any(), any()) :: term()
  def categorize("usage_rules", "elixir"), do: :elixir
  @spec categorize(any(), any()) :: term()
  def categorize("usage_rules", "otp"), do: :elixir
  @spec categorize(any(), any()) :: term()
  def categorize("usage_rules", _), do: :elixir
  @spec categorize(any(), any()) :: term()
  def categorize(_, _), do: :elixir

  @doc "Determine which project types a dep's rules apply to."
  @spec applies_to(any()) :: term()
  def applies_to("ash" <> _), do: ["ash"]
  @spec applies_to(any()) :: term()
  def applies_to("phoenix"), do: ["phoenix"]
  @spec applies_to(any()) :: term()
  def applies_to(_), do: ["all"]

  @doc "Extract version string from a dep's mix.exs."
  @spec get_dep_version(any()) :: term()
  def get_dep_version(dep) do
    mix_exs = Path.join(["deps", dep, "mix.exs"])

    if File.exists?(mix_exs) do
      content = File.read!(mix_exs)

      case Regex.run(~r/@version\s+"([^"]+)"/, content) ||
             Regex.run(~r/version:\s+"([^"]+)"/, content) do
        [_, v] -> "v#{v}"
        _ -> nil
      end
    end
  end

  @doc "Get description from a dep's mix.exs."
  @spec get_dep_description(any()) :: term()
  def get_dep_description(dep) do
    mix_exs = Path.join(["deps", dep, "mix.exs"])

    if File.exists?(mix_exs) do
      content = File.read!(mix_exs)

      case Regex.run(~r/description:\s+"([^"]+)"/, content) do
        [_, desc] -> desc
        _ -> nil
      end
    end
  end

  @doc "Find all usage-rules files for a dependency."
  @spec find_rule_files(any()) :: term()
  def find_rule_files(dep_name) do
    dep_path = Path.join("deps", dep_name)

    main =
      case Path.join(dep_path, "usage-rules.md") do
        path -> if File.exists?(path), do: [path], else: []
      end

    subs = Path.wildcard(Path.join(dep_path, "usage-rules/*.md"))

    main ++ subs
  end

  @doc """
  Parse an AGENTS.md file (generated by phx.new) into rule attribute maps.
  Handles the mixed format: project guidelines + usage-rules sections.
  Strips usage-rules markers and parses both bullet-point rules and
  section-based content blocks.
  """
  @spec parse_agents_file(String.t(), any()) :: term()
  def parse_agents_file(path, library_name \\ "phoenix-framework") do
    content = File.read!(path)

    # Split into sections by ## headers
    sections = split_sections(content)

    Enum.flat_map(sections, fn {heading, body} ->
      sub = heading_to_sub_rule(heading)

      body
      |> String.split("\n")
      |> chunk_rules()
      |> Enum.filter(&(String.length(String.trim(&1)) >= @min_rule_length))
      |> Enum.map(fn rule_text ->
        rule_text = String.trim(rule_text)

        %{
          content: rule_text,
          content_hash: content_hash(rule_text),
          category: agents_categorize(sub, rule_text),
          severity: detect_severity(rule_text),
          source_project_slug: library_name,
          source_commit: nil,
          source_context: "#{library_name}:#{sub}",
          applies_to: ["phoenix"],
          tags: Enum.uniq([library_name, sub])
        }
      end)
    end)
  end

  defp split_sections(content) do
    # Remove HTML comment markers from usage_rules.sync
    content = Regex.replace(~r/<!--.*?-->/, content, "")

    lines = String.split(content, "\n")

    {sections, current_heading, current_lines} =
      Enum.reduce(lines, {[], "project", []}, fn line, {sections, heading, lines} ->
        if String.starts_with?(line, "## ") do
          section = {heading, Enum.join(Enum.reverse(lines), "\n")}

          new_heading =
            line
            |> String.trim_leading("## ")
            |> String.downcase()
            |> String.replace(~r/[^a-z0-9]+/, "-")
            |> String.trim("-")

          {[section | sections], new_heading, []}
        else
          {sections, heading, [line | lines]}
        end
      end)

    final = {current_heading, Enum.join(Enum.reverse(current_lines), "\n")}
    Enum.reverse([final | sections])
  end

  defp heading_to_sub_rule(heading) do
    heading
    |> String.replace(~r/guidelines$/, "")
    |> String.trim("-")
    |> String.trim()
    |> case do
      "" -> "main"
      s -> s
    end
  end

  # Category from section heading — with content-based fallback
  defp agents_categorize(sub, _content) when sub in ["js-and-css", "ui-ux", "ui-ux-design"],
    do: :css

  defp agents_categorize("elixir", _content), do: :elixir
  defp agents_categorize("mix", _content), do: :elixir

  defp agents_categorize(sub, _content) when sub in ["test", "liveview-tests", "testing"],
    do: :testing

  defp agents_categorize("phoenix-html", _content), do: :heex

  defp agents_categorize(sub, _content)
       when sub in ["phoenix-liveview", "liveview-streams", "liveview-javascript"],
       do: :liveview

  defp agents_categorize("phoenix-v1-8" <> _, _content), do: :liveview
  defp agents_categorize("phoenix-liveview" <> _, _content), do: :liveview
  defp agents_categorize("liveview-javascript" <> _, _content), do: :liveview
  defp agents_categorize("phoenix", _content), do: :routing

  # Fallback: classify by content keywords
  defp agents_categorize(_sub, content) do
    content_lower = String.downcase(content)

    cond do
      String.contains?(content_lower, ["ash.", "ash_", "changeset", "resource "]) ->
        :ash

      String.contains?(content_lower, ["liveview", "live_view", "socket", "handle_event", "phx-"]) ->
        :liveview

      String.contains?(content_lower, ["heex", "~h\"", ".heex", "<."]) ->
        :heex

      String.contains?(content_lower, ["genserver", "supervisor", "otp", "application.start"]) ->
        :elixir

      String.contains?(content_lower, ["mix test", "assert ", "exunit", "test \""]) ->
        :testing

      String.contains?(content_lower, ["router", "route", "plug ", "pipeline"]) ->
        :routing

      String.contains?(content_lower, ["tailwind", "css", "daisyui"]) ->
        :css

      String.contains?(content_lower, ["git ", "branch", "commit", "deploy"]) ->
        :architecture

      String.contains?(content_lower, ["task", "agent", "maestro", "coordinate"]) ->
        :architecture

      true ->
        :architecture
    end
  end

  @doc """
  Parse a startup.json file into rule attribute maps.
  Extracts rules from embedded markdown in source_files, anti_patterns, workflow, etc.
  """
  @spec parse_startup_json(String.t(), any()) :: term()
  def parse_startup_json(path, library_name \\ "maestro-startup") do
    json = path |> File.read!() |> Jason.decode!()
    basename = String.downcase(Path.basename(path, ".json"))

    # Collect all string values from the JSON recursively
    text_values = extract_json_texts(json)

    # Parse each text value as potential markdown containing rules
    text_values
    |> Enum.flat_map(fn text ->
      text
      |> String.split("\n")
      |> chunk_rules()
      |> Enum.filter(&(String.length(String.trim(&1)) >= @min_rule_length))
    end)
    |> Enum.map(fn rule_text ->
      rule_text = String.trim(rule_text)

      %{
        content: rule_text,
        content_hash: content_hash(rule_text),
        category: startup_categorize(basename),
        severity: detect_severity(rule_text),
        source_project_slug: library_name,
        source_commit: nil,
        source_context: "#{library_name}:#{basename}",
        applies_to: ["all"],
        tags: Enum.uniq([library_name, basename])
      }
    end)
  end

  # Recursively extract all string values from a JSON structure
  defp extract_json_texts(value) when is_binary(value) and byte_size(value) >= 40, do: [value]

  defp extract_json_texts(value) when is_map(value),
    do: Enum.flat_map(Map.values(value), &extract_json_texts/1)

  defp extract_json_texts(value) when is_list(value),
    do: Enum.flat_map(value, &extract_json_texts/1)

  defp extract_json_texts(_), do: []

  defp startup_categorize("critical_10"), do: :architecture
  defp startup_categorize("guidelines"), do: :architecture
  defp startup_categorize("user_context"), do: :architecture
  defp startup_categorize("agent_operations_patterns"), do: :architecture
  defp startup_categorize("agents_symlink"), do: :architecture
  defp startup_categorize(_), do: :architecture

  @doc """
  Parse a directory of Claude memory markdown files into rule attribute maps.
  Each file's body (after frontmatter) becomes one candidate rule.
  """
  @spec parse_memory_dir(any(), any()) :: term()
  def parse_memory_dir(dir, library_name \\ "claude-memory") do
    Path.wildcard(Path.join(dir, "*.md"))
    |> Enum.reject(&String.ends_with?(&1, "MEMORY.md"))
    |> Enum.flat_map(fn path ->
      content = File.read!(path)
      {frontmatter, body} = split_frontmatter(content)
      body = String.trim(body)

      if String.length(body) >= @min_rule_length do
        name = frontmatter["name"] || Path.basename(path, ".md")
        type = frontmatter["type"] || "project"

        [
          %{
            content: body,
            content_hash: content_hash(body),
            category: memory_categorize(type),
            severity: memory_severity(type),
            source_project_slug: library_name,
            source_commit: nil,
            source_context: "#{library_name}:#{name}",
            applies_to: ["all"],
            tags: [library_name, type]
          }
        ]
      else
        []
      end
    end)
  end

  defp split_frontmatter(content) do
    case Regex.run(~r/\A---\n(.*?)\n---\n(.*)\z/s, content) do
      [_, fm, body] ->
        parsed =
          fm
          |> String.split("\n")
          |> Enum.reduce(%{}, fn line, acc ->
            case String.split(line, ": ", parts: 2) do
              [key, val] -> Map.put(acc, String.trim(key), String.trim(val))
              _ -> acc
            end
          end)

        {parsed, body}

      _ ->
        {%{}, content}
    end
  end

  defp memory_categorize("feedback"), do: :architecture
  defp memory_categorize("user"), do: :architecture
  defp memory_categorize("project"), do: :architecture
  defp memory_categorize("reference"), do: :architecture
  defp memory_categorize(_), do: :architecture

  defp memory_severity("feedback"), do: :should
  defp memory_severity(_), do: :prefer

  @doc "Extract sub-rule name from a file path."
  @spec sub_rule_name(String.t()) :: term()
  def sub_rule_name(path) do
    parts = path |> Path.relative_to("deps") |> String.split("/")

    case parts do
      [_, "usage-rules", file] -> String.replace_suffix(file, ".md", "")
      [_, "usage-rules.md"] -> "main"
      _ -> Path.basename(path, ".md")
    end
  end
end
