defmodule Maestro.Resources.TagHierarchy do
  use Ash.Resource,
    domain: Maestro.Resources,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "tag_hierarchies"
    repo Maestro.Repo
  end

  attributes do
    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :parent_tag, Maestro.Resources.Tag do
      allow_nil? false
      attribute_type :integer
    end

    belongs_to :child_tag, Maestro.Resources.Tag do
      allow_nil? false
      attribute_type :integer
    end
  end

  actions do
    defaults [:read, :create, :destroy]
  end

  identities do
    identity :unique_tag_hierarchy, [:parent_tag_id, :child_tag_id]
  end

  code_interface do
    define :create
    define :read
    define :destroy
  end
end
