defmodule Maestro.Resources.Tag do
  use Ash.Resource,
    domain: Maestro.Resources,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "tags"
    repo Maestro.Repo
  end

  attributes do
    integer_primary_key :id

    attribute :name, :string do
      allow_nil? false
    end

    attribute :slug, :string do
      allow_nil? false
    end

    attribute :description, :string

    attribute :color, :string

    attribute :owner_type, :string do
      allow_nil? false
      default "User"
    end

    attribute :owner_id, :string do
      allow_nil? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    many_to_many :resources, Maestro.Resources.Resource do
      through Maestro.Resources.ResourceTag
      source_attribute_on_join_resource :tag_id
      destination_attribute_on_join_resource :resource_id
    end

    many_to_many :parent_tags, __MODULE__ do
      through Maestro.Resources.TagHierarchy
      source_attribute_on_join_resource :child_tag_id
      destination_attribute_on_join_resource :parent_tag_id
    end

    many_to_many :child_tags, __MODULE__ do
      through Maestro.Resources.TagHierarchy
      source_attribute_on_join_resource :parent_tag_id
      destination_attribute_on_join_resource :child_tag_id
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :slug, :description, :color, :owner_type, :owner_id]
    end

    update :update do
      accept [:name, :slug, :description, :color]
    end
  end

  identities do
    identity :unique_slug_per_owner, [:slug, :owner_type, :owner_id]
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :by_id, get_by: [:id], action: :read
    define :by_slug, get_by: [:slug], action: :read
  end
end
