defmodule Maestro.Ops.Rule.Changes.InferDirective do
  @moduledoc """
  Sets a rule's directive from explicit legacy wording when callers omit it.

  Explicit action input wins. A missing persisted directive is inferred at the
  Ash boundary, keeping older importers and API clients compatible. Once stored,
  the directive remains authoritative when prose changes.
  """

  use Ash.Resource.Change

  alias Maestro.Ops.RuleDirective

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.fetch_change(changeset, :directive) do
      {:ok, directive} when not is_nil(directive) ->
        changeset

      _missing_or_nil ->
        set_inferred_directive(changeset, Ash.Changeset.get_attribute(changeset, :content))
    end
  end

  defp set_inferred_directive(changeset, content) when is_binary(content) do
    Ash.Changeset.force_change_attribute(changeset, :directive, RuleDirective.infer(content))
  end

  defp set_inferred_directive(changeset, _content), do: changeset
end
