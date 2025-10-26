defmodule Maestro.Ops.Project do
  use Ash.Resource,
    otp_app: :maestro,
    domain: Maestro.Ops,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "projects"
    repo Maestro.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :slug, :description, :web_port, :debugger_port, :github_url]
    end

    update :update do
      primary? true
      accept [:name, :slug, :description, :web_port, :debugger_port, :github_url, :status]
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

    attribute :status, :atom do
      constraints one_of: [:unknown, :running, :stopped]
      default :unknown
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_slug, [:slug]
    identity :unique_web_port, [:web_port]
  end
end
