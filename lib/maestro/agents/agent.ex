defmodule Maestro.Agents.Agent do
  @moduledoc """
  Agent resource.
  """
  use Ash.Resource,
    otp_app: :maestro,
    domain: Maestro.Agents,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "agents"
    repo Maestro.Repo
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :by_name, args: [:name]
    define :by_type, args: [:type]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :type, :model, :description]
    end

    update :update do
      primary? true
      accept [:name, :type, :model, :description]
    end

    read :by_name do
      argument :name, :string, allow_nil?: false
      filter expr(name == ^arg(:name))
    end

    read :by_type do
      argument :type, :atom, allow_nil?: false
      filter expr(type == ^arg(:type))
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
      description "Agent identifier, e.g. 'claude-code', 'calvin'"
    end

    attribute :type, :atom do
      constraints one_of: [:claude_code, :cursor, :copilot, :custom]
      allow_nil? false
      public? true
      description "Agent platform type"
    end

    attribute :model, :string do
      public? true
      description "Model being used, e.g. 'claude-opus-4-6'"
    end

    attribute :description, :string do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :sessions, Maestro.Agents.Session
    has_many :requests, Maestro.Agents.Request
  end
end
