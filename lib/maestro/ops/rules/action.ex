defmodule Maestro.Ops.Rules.Action do
  @moduledoc """
  Per-rule actions. Each function takes ONE rule id (or struct) and returns
  a result for that single rule. These are the unit of work for
  `Maestro.Ops.Rules.Runner`.

  Actions here are intentionally dumb about how the rule was selected —
  that's the selector's job (`Inspector`, a cinder query, a manual list).
  """

  import Ecto.Query
  alias Maestro.Ops.Rule
  alias Maestro.Repo
  alias Maestro.Ops.Rules.Triage

  @type result :: {:ok, map()} | {:error, term()}

  @doc """
  Re-score one rule through Triage and return a diff vs. its current status.
  Read-only — never mutates. Result shape:

      %{
        id: "...",
        current_status: :retired,
        current_reason: "Too short to be actionable",
        triage_decision: :approved,
        content_preview: "...",
        verdict: :would_rescue | :agrees | :would_demote | :no_change
      }
  """
  @spec diagnose(String.t() | map()) :: result()
  def diagnose(id_or_rule) do
    with {:ok, rule} <- fetch(id_or_rule) do
      decision = Triage.decide(rule.content, rule.source_project_slug)

      current = atomize(rule.status)

      verdict =
        cond do
          current == decision.status -> :agrees
          current == :retired and decision.status == :approved -> :would_rescue
          current == :approved and decision.status == :retired -> :would_demote
          true -> :no_change
        end

      {:ok,
       %{
         id: rule.id,
         current_status: current,
         current_reason: rule.retired_reason,
         triage_decision: decision.status,
         triage_reason: Map.get(decision, :reason),
         verdict: verdict,
         content_preview: preview(rule.content)
       }}
    end
  end

  @doc "Apply the Triage decision to the rule — mutates status accordingly."
  @spec re_triage(String.t() | map()) :: result()
  def re_triage(id_or_rule) do
    with {:ok, rule} <- fetch(id_or_rule),
         decision = Triage.decide(rule.content, rule.source_project_slug),
         :ok <- apply_decision(rule, decision) do
      {:ok,
       %{
         id: rule.id,
         from: atomize(rule.status),
         to: decision.status,
         reason: Map.get(decision, :reason)
       }}
    end
  end

  # --- Helpers ---

  defp fetch(%{id: _} = rule), do: {:ok, rule}

  defp fetch(id) when is_binary(id) do
    row =
      Repo.one(
        from r in "rules",
          where: r.id == type(^id, :binary_id),
          limit: 1,
          select: %{
            id: type(r.id, :string),
            status: r.status,
            content: r.content,
            source_project_slug: r.source_project_slug,
            retired_reason: r.retired_reason
          }
      )

    case row do
      nil -> {:error, {:not_found, id}}
      rule -> {:ok, rule}
    end
  end

  defp apply_decision(rule, %{status: :approved}), do: call(Rule, :approve, rule)

  defp apply_decision(rule, %{status: :retired, reason: reason}),
    do: call(Rule, :retire, rule, %{retired_reason: reason})

  defp apply_decision(rule, %{status: :linter} = d),
    do: call(Rule, :mark_linter, rule, Map.get(d, :lint, %{}))

  defp apply_decision(_rule, _), do: :ok

  defp call(mod, fun, rule), do: call(mod, fun, rule, %{})

  defp call(mod, fun, %{id: id}, args) do
    case apply(mod, fun, [id, args]) do
      {:ok, _} -> :ok
      :ok -> :ok
      {:error, e} -> {:error, e}
      other -> {:error, other}
    end
  end

  defp atomize(nil), do: nil
  defp atomize(v) when is_atom(v), do: v
  defp atomize(v) when is_binary(v), do: String.to_existing_atom(v)

  defp preview(nil), do: ""
  defp preview(s), do: s |> String.replace(~r/\n+/, " ") |> String.slice(0, 110)
end
