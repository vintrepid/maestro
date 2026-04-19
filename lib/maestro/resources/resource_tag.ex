defmodule Maestro.Resources.ResourceTag do
  @moduledoc """
  Resource Tag resource.
  """
  use Ash.Resource,
    domain: Maestro.Resources,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  json_api do
    type "resource_tags"

    routes do
      base "/resource-tags"
      index :read
      get :read
      post :create
      delete :destroy
    end
  end

  postgres do
    table "resource_tags"
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
    belongs_to :resource, Maestro.Resources.Resource do
      allow_nil? false
      attribute_type :integer
    end

    belongs_to :tag, Maestro.Resources.Tag do
      allow_nil? false
      attribute_type :integer
    end
  end

  identities do
    identity :unique_resource_tag, [:resource_id, :tag_id]
  end
end
