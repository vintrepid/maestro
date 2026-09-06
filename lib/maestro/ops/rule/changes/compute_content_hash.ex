defmodule Maestro.Ops.Rule.Changes.ComputeContentHash do
  @moduledoc false
  use Ash.Resource.Change

  @impl true
  @spec change(Ash.Changeset.t(), keyword(), map()) :: Ash.Changeset.t()
  def change(changeset, _opts, _context) do
    case Ash.Changeset.fetch_change(changeset, :content_hash) do
      {:ok, hash} when is_binary(hash) and hash != "" ->
        changeset

      _missing_or_nil ->
        put_computed_hash(changeset)
    end
  end

  defp put_computed_hash(changeset) do
    case Ash.Changeset.get_attribute(changeset, :content) do
      content when is_binary(content) ->
        directive = Ash.Changeset.get_attribute(changeset, :directive)

        Ash.Changeset.force_change_attribute(
          changeset,
          :content_hash,
          Maestro.Ops.RuleParser.content_hash(content, directive)
        )

      _missing_content ->
        changeset
    end
  end
end
