defmodule Maestro.Resources.Resource do
  @moduledoc """
  Resource resource.
  """
  use Ash.Resource,
    domain: Maestro.Resources,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  json_api do
    type "resources"

    routes do
      base "/resources"
      index :read
      get :read
      delete :destroy
    end
  end

  postgres do
    table "resources"
    repo Maestro.Repo
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :by_id, get_by: [:id], action: :read
    define :refresh_dot_workspace
    define :dot_work_packet
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :title,
        :description,
        :resource_type,
        :url,
        :file_path,
        :content,
        :thumbnail_url,
        :platform,
        :metadata,
        :owner_type,
        :owner_id
      ]
    end

    update :update do
      accept [
        :title,
        :description,
        :resource_type,
        :url,
        :file_path,
        :content,
        :thumbnail_url,
        :platform,
        :metadata
      ]
    end

    action :refresh_dot_workspace, :map do
      argument :apply, :boolean, default: false
      run Maestro.Ops.DotWorkspace
    end

    action :dot_work_packet, :map do
      run Maestro.Ops.DotWorkspace
    end
  end

  attributes do
    integer_primary_key :id

    attribute :title, :string do
      allow_nil? false
    end

    attribute :description, :string

    attribute :resource_type, :atom do
      constraints one_of: [:file, :directory, :website, :article, :conversation, :other]
      default :website
      allow_nil? false
    end

    attribute :url, :string

    attribute :file_path, :string

    attribute :content, :string

    attribute :thumbnail_url, :string

    attribute :platform, :string

    attribute :metadata, :map do
      default %{}
    end

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
    many_to_many :tags, Maestro.Resources.Tag do
      through Maestro.Resources.ResourceTag
      source_attribute_on_join_resource :resource_id
      destination_attribute_on_join_resource :tag_id
    end
  end
end
