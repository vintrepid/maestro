defmodule Maestro.Resources.ResourceTag do
  use Ash.Resource,
    domain: Maestro.Resources,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "resource_tags"
    repo Maestro.Repo
  end

  attributes do
    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :resource, Maestro.Resources.Resource do
      allow_nil? false
      attribute_type :integer
    end

    belongs_to :tag, Maestro.Resources.Tag do
      allow_nil? false
      attribute_type :integer
    end
  end

  actions do
    defaults [:read, :create, :destroy]
  end

  identities do
    identity :unique_resource_tag, [:resource_id, :tag_id]
  end

  code_interface do
    define :create
    define :read
    define :destroy
  end
end
