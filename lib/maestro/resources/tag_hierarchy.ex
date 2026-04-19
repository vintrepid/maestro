defmodule Maestro.Resources.TagHierarchy do
  @moduledoc """
  Tag Hierarchy resource.
  """
  use Ash.Resource,
    domain: Maestro.Resources,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  json_api do
    type "tag_hierarchies"

    routes do
      base "/tag-hierarchies"
      index :read
      get :read
      post :create
      delete :destroy
    end
  end

  postgres do
    table "tag_hierarchies"
    repo Maestro.Repo
  end

  code_interface do
    define :create
    define :read
    define :destroy
  end

  actions do
    defaults [:read, :create, :destroy]
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

  identities do
    identity :unique_tag_hierarchy, [:parent_tag_id, :child_tag_id]
  end
end
