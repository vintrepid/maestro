defmodule Maestro.Ops.RuleSource do
  @moduledoc """
  Rule Source resource.
  """
  use Ash.Resource,
    otp_app: :maestro,
    domain: Maestro.Ops,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  json_api do
    type "rule_sources"

    routes do
      base "/rule-sources"
      index :read
      get :read
    end
  end

  postgres do
    table "rule_sources"
    repo Maestro.Repo

    references do
      reference :library, on_delete: :delete
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :file_path,
        :sub_rule_name,
        :content_hash,
        :rule_count,
        :last_synced_at,
        :library_id
      ]

      upsert? true
      upsert_identity :unique_path
      upsert_fields [:content_hash, :rule_count, :last_synced_at]
    end

    update :update do
      primary? true
      accept [:content_hash, :rule_count, :last_synced_at]
    end
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :file_path, :string do
      allow_nil? false
      public? true
      description "Relative path to usage-rules file (e.g. deps/ash/usage-rules/actions.md)"
    end

    attribute :sub_rule_name, :string do
      public? true
      description "Sub-rule name (e.g. actions, testing) or main"
    end

    attribute :content_hash, :string do
      public? true
      description "SHA256 of file content for change detection"
    end

    attribute :rule_count, :integer do
      default 0
      public? true
      description "Number of rules extracted from this file"
    end

    attribute :last_synced_at, :utc_datetime_usec do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :library, Maestro.Ops.Library do
      allow_nil? false
      public? true
    end

    has_many :rules, Maestro.Ops.Rule
  end

  identities do
    identity :unique_path, [:library_id, :file_path]
  end
end
