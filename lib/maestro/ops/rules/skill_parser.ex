defmodule Maestro.Ops.Rules.SkillParser do
  @moduledoc """
  Pure functions for discovering and parsing skill files.
  No DB access — returns data structures for the caller to persist.
  """

  @doc "Discover all skills on disk and return their parsed attributes."
  def discover(skills_dir \\ ".claude/skills") do
    Path.wildcard(Path.join(skills_dir, "*/SKILL.md"))
    |> Enum.map(&parse_skill_path/1)
  end

  @doc "Parse a single SKILL.md file path into attribute map."
  def parse_skill_path(skill_path) do
    skill_dir = Path.dirname(skill_path)
    skill_name = Path.basename(skill_dir)
    content = File.read!(skill_path)
    {frontmatter, _body} = parse_frontmatter(content)

    references =
      Path.wildcard(Path.join(skill_dir, "references/*.md"))
      |> Enum.map(&Path.relative_to_cwd/1)

    library_names = Enum.map(references, &Path.basename(&1, ".md"))

    %{
      name: skill_name,
      description: frontmatter["description"],
      skill_path: skill_dir,
      managed_by: get_in(frontmatter, ["metadata", "managed-by"]) || "manual",
      library_names: library_names,
      reference_files: references
    }
  end

  @doc "Parse YAML-ish frontmatter from a SKILL.md file."
  def parse_frontmatter(content) do
    case String.split(content, "---\n", parts: 3) do
      ["", yaml, body] -> {parse_yaml(yaml), body}
      _ -> {%{}, content}
    end
  end

  defp parse_yaml(yaml) do
    yaml
    |> String.split("\n")
    |> Enum.reduce(%{}, fn line, acc ->
      case String.split(line, ": ", parts: 2) do
        [key, value] ->
          key = String.trim(key)
          value = value |> String.trim() |> String.trim("\"")

          if String.starts_with?(key, "  ") do
            # Nested key under last parent
            parent = acc |> Map.keys() |> List.last()

            if parent && is_map(Map.get(acc, parent, nil)) do
              Map.update!(acc, parent, &Map.put(&1, String.trim(key), value))
            else
              acc
            end
          else
            Map.put(acc, key, value)
          end

        _ ->
          key = String.trim_trailing(line, ":")
          if key != "" and not String.contains?(key, " "),
            do: Map.put(acc, key, %{}),
            else: acc
      end
    end)
  end
end
