defmodule Maestro.Ops.AgentSession do
  @moduledoc """
  A configured agent deployment with a curated set of rules.

  An AgentSession represents an agent working on a specific project with a specific
  scope (bundle). It owns a many-to-many relationship with Rules through
  AgentSessionRule, so the rule set can be curated in the UI.

  The worktree tool creates sessions and populates rules from bundle categories.
  The Rules UI filters by session to show/edit the rule set.
  CLAUDE.md generation reads from the session's rules, not ad-hoc category filters.
  """

  use Ash.Resource,
    otp_app: :maestro,
    domain: Maestro.Ops,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "ops_agent_sessions"
    repo Maestro.Repo
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :active
    define :by_id, get_by: [:id], action: :read
    define :for_project, args: [:project_id]
    define :complete
    define :add_rule, args: [:rule_id]
    define :remove_rule, args: [:rule_id]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :name,
        :project_id,
        :bundle,
        :purpose,
        :worktree_path,
        :branch_name
      ]

      change set_attribute(:status, :active)
    end

    update :update do
      primary? true
      accept [:name, :purpose, :worktree_path, :status]
    end

    update :complete do
      accept []
      change set_attribute(:status, :completed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
    end

    update :add_rule do
      argument :rule_id, :uuid, allow_nil?: false

      change manage_relationship(:rule_id, :rules,
        on_no_match: :error,
        on_match: :ignore,
        value_is_key: :id,
        type: :append
      )
    end

    update :remove_rule do
      argument :rule_id, :uuid, allow_nil?: false

      change manage_relationship(:rule_id, :rules,
        on_no_match: :ignore,
        on_match: :unrelate,
        value_is_key: :id,
        type: :remove
      )
    end

    read :active do
      filter expr(status == :active)
      prepare build(sort: [inserted_at: :desc])
    end

    read :for_project do
      argument :project_id, :string, allow_nil?: false
      filter expr(project_id == ^arg(:project_id) and status == :active)
      prepare build(sort: [inserted_at: :desc])
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
      description "Display name, e.g. 'Calvin Domain Agent'"
    end

    attribute :project_id, :string do
      allow_nil? false
      public? true
      description "Project slug, e.g. 'calvin'"
    end

    attribute :bundle, :atom do
      constraints one_of: [:model, :ui, :universal]
      allow_nil? false
      public? true
      description "Rule bundle type that seeded the initial rule set"
    end

    attribute :purpose, :string do
      public? true
      description "What this agent is working on"
    end

    attribute :status, :atom do
      constraints one_of: [:active, :completed]
      default :active
      public? true
    end

    attribute :worktree_path, :string do
      public? true
      description "Filesystem path to the agent's git worktree"
    end

    attribute :branch_name, :string do
      public? true
      description "Git branch name for this agent's work"
    end

    attribute :completed_at, :utc_datetime_usec do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    many_to_many :rules, Maestro.Ops.Rule do
      public? true
      through Maestro.Ops.AgentSessionRule
      source_attribute_on_join_resource :agent_session_id
      destination_attribute_on_join_resource :rule_id
    end
  end
end
