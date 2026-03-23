defmodule Maestro.Ops.Rules.Prioritizer do
  @moduledoc """
  Auto-assigns priority scores and bundles to rules based on content analysis.
  Run via `mix maestro.rules.export --prioritize` or called directly.
  """

  import Ecto.Query
  alias Maestro.Repo

  @doc """
  Assigns priority and bundle to all approved rules that haven't been manually set.
  Returns {updated_count, skipped_count}.
  """
  def auto_assign_all do
    rules = Repo.all(
      from r in "rules",
        where: r.status == "approved",
        select: %{
          id: type(r.id, :string),
          content: r.content,
          category: r.category,
          severity: r.severity,
          priority: r.priority,
          bundle: r.bundle
        }
    )

    results = Enum.map(rules, fn rule ->
      new_priority = compute_priority(rule)
      new_bundle = compute_bundle(rule)

      if new_priority != rule.priority || new_bundle != (rule.bundle || "universal") do
        {:ok, uuid} = Ecto.UUID.dump(rule.id)
        Repo.query!(
          "UPDATE rules SET priority = $1, bundle = $2, updated_at = NOW() WHERE id = $3",
          [new_priority, to_string(new_bundle), uuid]
        )
        :updated
      else
        :skipped
      end
    end)

    updated = Enum.count(results, &(&1 == :updated))
    skipped = Enum.count(results, &(&1 == :skipped))
    {updated, skipped}
  end

  @doc """
  Computes a priority score (1-100) for a rule based on signals.
  """
  def compute_priority(rule) do
    base = severity_base(rule.severity)
    content = String.downcase(rule.content || "")

    boosts = [
      # "Never" and "Always" rules are high priority
      if(String.contains?(content, "never"), do: 15, else: 0),
      if(String.contains?(content, "always"), do: 10, else: 0),
      # Rules with "why" explanations are well-curated
      if(String.contains?(content, "why:") or String.contains?(content, "**why"), do: 5, else: 0),
      # Rules about security are high priority
      if(rule.category == "security", do: 15, else: 0),
      # Architecture rules are foundational
      if(rule.category == "architecture", do: 10, else: 0),
      # Short, clear rules are more actionable
      if(String.length(rule.content || "") < 200, do: 5, else: 0),
      # Rules with code examples are more useful
      if(String.contains?(content, "```"), do: 5, else: 0),
      # Penalty for very long rules (hard to follow)
      if(String.length(rule.content || "") > 500, do: -10, else: 0)
    ]

    (base + Enum.sum(boosts))
    |> max(1)
    |> min(100)
  end

  @doc """
  Determines which bundle a rule belongs to based on category and content.
  """
  def compute_bundle(rule) do
    content = String.downcase(rule.content || "")
    category = rule.category

    cond do
      # Maestro-specific
      String.contains?(content, "maestro") and
        not String.contains?(content, "maestroweb") ->
        "maestro"

      String.contains?(content, "current_task.json") ->
        "maestro"

      String.contains?(content, "agent_dashboard") ->
        "maestro"

      String.contains?(content, "lib/maestro/") ->
        "maestro"

      # UI bundle
      category in ~w(liveview heex css components forms routing pubsub) ->
        "ui"

      # Model bundle
      category in ~w(ash elixir testing) ->
        "model"

      # Architecture and security stay universal
      category in ~w(architecture security) ->
        "universal"

      # Default
      true ->
        "universal"
    end
  end

  defp severity_base("must"), do: 70
  defp severity_base(:must), do: 70
  defp severity_base("should"), do: 40
  defp severity_base(:should), do: 40
  defp severity_base(_), do: 20
end
