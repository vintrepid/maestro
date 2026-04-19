defmodule Maestro.Ops.Project do
  @moduledoc """
  Project resource.
  """
  use Ash.Resource,
    otp_app: :maestro,
    domain: Maestro.Ops,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  json_api do
    type "projects"

    routes do
      base "/projects"
      index :read
      get :read
    end
  end

  postgres do
    table "projects"
    repo Maestro.Repo
  end

  code_interface do
    define :create
    define :read
    define :active
    define :update
    define :destroy
    define :by_id, get_by: [:id], action: :read
  end

  actions do
    defaults [:read, :destroy]

    read :active do
      filter expr(status != :inactive)
    end

    create :create do
      primary? true
      accept [:name, :slug, :description, :web_port, :debugger_port, :github_url, :prod_url]
    end

    update :update do
      primary? true

      accept [
        :name,
        :slug,
        :description,
        :web_port,
        :debugger_port,
        :github_url,
        :prod_url,
        :status
      ]
    end
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      public? true
    end

    attribute :web_port, :integer do
      allow_nil? false
      public? true
    end

    attribute :debugger_port, :integer do
      public? true
    end

    attribute :github_url, :string do
      public? true
    end

    attribute :prod_url, :string do
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:unknown, :running, :stopped, :inactive]
      default :unknown
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_slug, [:slug]
  end
end
