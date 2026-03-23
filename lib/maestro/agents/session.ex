defmodule Maestro.Agents.Session do
  use Ash.Resource,
    otp_app: :maestro,
    domain: Maestro.Agents,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "agent_sessions"
    repo Maestro.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:agent_id, :task_description, :status, :metadata]
    end

    update :update do
      primary? true
      accept [:task_description, :status, :metadata, :ended_at]
    end

    update :finish do
      require_atomic? false
      accept []
      change set_attribute(:status, :completed)
      change set_attribute(:ended_at, &DateTime.utc_now/0)
    end

    update :fail do
      require_atomic? false
      accept [:metadata]
      change set_attribute(:status, :failed)
      change set_attribute(:ended_at, &DateTime.utc_now/0)
    end

    read :active do
      filter expr(status == :active)
    end

    read :by_agent do
      argument :agent_id, :uuid, allow_nil?: false
      filter expr(agent_id == ^arg(:agent_id))
    end
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :task_description, :string do
      public? true
      description "What this session is working on"
    end

    attribute :status, :atom do
      constraints one_of: [:active, :completed, :failed]
      default :active
      public? true
    end

    attribute :metadata, :map do
      default %{}
      public? true
      description "Arbitrary session metadata — mix task args, context, etc."
    end

    attribute :ended_at, :utc_datetime_usec do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :agent, Maestro.Agents.Agent do
      allow_nil? false
      public? true
    end

    has_many :requests, Maestro.Agents.Request
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :finish
    define :fail
    define :active
    define :by_agent, args: [:agent_id]
  end
end
