defmodule Mix.Tasks.Maestro.Rule.Propose do
  @moduledoc """
  Propose a new rule with provenance.

  ## Usage

      mix maestro.rule.propose --content "Never use raw Ecto when Ash is available" \\
        --category ash --severity must \\
        --source-project calvin --source-commit abc1234 \\
        --context "Agent used from() query instead of Ash action, broke authorization"

  ## Options

    * `--content` (required) - The rule text
    * `--category` (required) - One of: architecture, liveview, ash, heex, css, elixir,
      testing, deployment, pubsub, forms, components, routing, security
    * `--severity` - must, should, or prefer (default: should)
    * `--source-project` - Project slug where rule was discovered
    * `--source-commit` - Git SHA that proved this rule
    * `--context` - Why this rule exists
    * `--tags` - Comma-separated tags for skill grouping
    * `--applies-to` - Comma-separated: all, ash, phoenix, liveview (default: all)
  """

  use Mix.Task
  @shortdoc "Propose a new agent rule with provenance"

  @spec run([String.t()]) :: :ok
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          content: :string,
          category: :string,
          severity: :string,
          source_project: :string,
          source_commit: :string,
          context: :string,
          tags: :string,
          applies_to: :string
        ],
        aliases: [c: :content, k: :category, s: :severity, p: :source_project]
      )

    content = opts[:content] || raise "Missing --content"
    category = opts[:category] || raise "Missing --category"

    attrs = %{
      content: content,
      category: String.to_existing_atom(category),
      severity: if(opts[:severity], do: String.to_existing_atom(opts[:severity]), else: :should),
      source_project_slug: opts[:source_project],
      source_commit: opts[:source_commit],
      source_context: opts[:context],
      tags:
        if(opts[:tags], do: Enum.map(String.split(opts[:tags], ","), &String.trim/1), else: []),
      applies_to:
        if(opts[:applies_to],
          do: Enum.map(String.split(opts[:applies_to], ","), &String.trim/1),
          else: ["all"]
        )
    }

    case Maestro.Ops.Rule.propose(attrs) do
      {:ok, rule} ->
        Mix.shell().info("""
        Rule proposed: #{rule.id}
          Category: #{rule.category}
          Severity: #{rule.severity}
          Source:   #{rule.source_project_slug || "unknown"}
          Status:   proposed (review in Maestro UI at /rules)
        """)

      {:error, error} ->
        Mix.shell().error("Failed to propose rule: #{inspect(error)}")
    end
  end
end
