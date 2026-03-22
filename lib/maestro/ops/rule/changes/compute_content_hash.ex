defmodule Maestro.Ops.Rule.Changes.ComputeContentHash do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :content_hash) do
      nil ->
        case Ash.Changeset.get_attribute(changeset, :content) do
          nil -> changeset
          content -> Ash.Changeset.force_change_attribute(changeset, :content_hash, Maestro.Ops.RuleParser.content_hash(content))
        end

      _already_set ->
        changeset
    end
  end
end
