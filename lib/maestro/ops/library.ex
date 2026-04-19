defmodule Maestro.Ops.Library do
  @moduledoc """
  Library resource.
  """
  use Ash.Resource,
    otp_app: :maestro,
    domain: Maestro.Ops,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  json_api do
    type "libraries"

    routes do
      base "/libraries"
      index :read
      get :read
    end
  end

  postgres do
    table "libraries"
    repo Maestro.Repo
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :by_name, get_by: [:name], action: :read
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :version, :description, :last_synced_at]
      upsert? true
      upsert_identity :unique_name
      upsert_fields [:version, :description, :last_synced_at]
    end

    update :update do
      primary? true
      accept [:version, :description, :last_synced_at]
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
      description "Dependency name (e.g. ash, phoenix)"
    end

    attribute :version, :string do
      public? true
      description "Current version from dep's mix.exs"
    end

    attribute :description, :string do
      public? true
      description "Package description"
    end

    attribute :last_synced_at, :utc_datetime_usec do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :rule_sources, Maestro.Ops.RuleSource
    has_many :rules, Maestro.Ops.Rule
  end

  identities do
    identity :unique_name, [:name]
  end
end
