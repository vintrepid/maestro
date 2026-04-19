defmodule Maestro.Ops.AgentSessionRule do
  @moduledoc """
  Join table linking AgentSessions to Rules.

  Each record represents a rule that has been selected for a particular agent session.
  Rules can be added/removed through the AgentSession's manage_relationship actions.
  """

  use Ash.Resource,
    otp_app: :maestro,
    domain: Maestro.Ops,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  json_api do
    type "agent_session_rules"

    routes do
      base "/agent-session-rules"
      index :read
      get :read
    end
  end

  postgres do
    table "agent_session_rules"
    repo Maestro.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:agent_session_id, :rule_id]
    end
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id
    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :agent_session, Maestro.Ops.AgentSession do
      public? true
      allow_nil? false
    end

    belongs_to :rule, Maestro.Ops.Rule do
      public? true
      allow_nil? false
    end
  end
end
