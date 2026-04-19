defmodule Maestro.Ops.Rules.Runner do
  @moduledoc """
  Applies a per-rule action (`Maestro.Ops.Rules.Action`) to a set of rule
  IDs and aggregates results.

  The runner is agnostic about:
  - *Where* the ids came from (Inspector selector, cinder filter, manual list).
  - *What* the action does (`diagnose`, `re_triage`, …).

  A set of one is just a selector that returned one id.
  """

  alias Maestro.Ops.Rules.Action

  @type action_fun :: (String.t() -> {:ok, map()} | {:error, term()})

  @doc """
  Run `action` over `ids`. Returns `{:ok, results}` where results is a list
  in input order.

  `action` is an atom naming a function on `Maestro.Ops.Rules.Action`
  (e.g. `:diagnose`) or a 1-arity function.
  """
  @spec run([String.t()], atom() | action_fun()) ::
          %{ok: [map()], errors: [term()], count: non_neg_integer()}
  def run(ids, action) when is_list(ids) do
    fun = resolve(action)

    {ok, errors} =
      ids
      |> Enum.map(fun)
      |> Enum.split_with(&match?({:ok, _}, &1))

    %{
      ok: Enum.map(ok, fn {:ok, v} -> v end),
      errors: Enum.map(errors, fn {:error, e} -> e end),
      count: length(ids)
    }
  end

  defp resolve(fun) when is_function(fun, 1), do: fun
  defp resolve(name) when is_atom(name), do: fn id -> apply(Action, name, [id]) end
end
