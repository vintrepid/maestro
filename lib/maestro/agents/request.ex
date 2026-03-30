defmodule Maestro.Agents.Request do
  @moduledoc """
  Request resource.
  """
  use Ash.Resource,
    otp_app: :maestro,
    domain: Maestro.Agents,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "agent_requests"
    repo Maestro.Repo
  end

  code_interface do
    define :create
    define :read
    define :destroy
    define :respond
    define :by_session, args: [:session_id]
    define :by_agent, args: [:agent_id]
    define :recent
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:agent_id, :session_id, :kind, :content, :metadata]

      change fn changeset, _ctx ->
        Ash.Changeset.after_action(changeset, fn _changeset, request ->
          Maestro.Agents.PubSub.broadcast_request(request)
          {:ok, request}
        end)
      end
    end

    update :respond do
      require_atomic? false
      accept [:response, :response_metadata, :duration_ms]
      change set_attribute(:responded_at, &DateTime.utc_now/0)

      change fn changeset, _ctx ->
        Ash.Changeset.after_action(changeset, fn _changeset, request ->
          Maestro.Agents.PubSub.broadcast_response(request)
          {:ok, request}
        end)
      end
    end

    read :by_session do
      argument :session_id, :uuid, allow_nil?: false
      filter expr(session_id == ^arg(:session_id))
    end

    read :by_agent do
      argument :agent_id, :uuid, allow_nil?: false
      filter expr(agent_id == ^arg(:agent_id))
    end

    read :recent do
      prepare build(sort: [inserted_at: :desc], limit: 50)
    end
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :kind, :atom do
      constraints one_of: [:user_prompt, :tool_call, :tool_result, :agent_response, :system]
      allow_nil? false
      public? true
      description "What type of request/event this is"
    end

    attribute :content, :string do
      allow_nil? false
      public? true
      description "The request content — user prompt, tool call, etc."
    end

    attribute :response, :string do
      public? true
      description "The response content"
    end

    attribute :metadata, :map do
      default %{}
      public? true
      description "Request metadata — tool name, params, etc."
    end

    attribute :response_metadata, :map do
      default %{}
      public? true
      description "Response metadata — token counts, model, etc."
    end

    attribute :duration_ms, :integer do
      public? true
      description "How long the request took to complete"
    end

    attribute :responded_at, :utc_datetime_usec do
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

    belongs_to :session, Maestro.Agents.Session do
      allow_nil? true
      public? true
    end
  end
end
