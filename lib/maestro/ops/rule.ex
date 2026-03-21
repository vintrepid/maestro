defmodule Maestro.Ops.Rule do
  use Ash.Resource,
    otp_app: :maestro,
    domain: Maestro.Ops,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "rules"
    repo Maestro.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [
        :content, :category, :severity, :source_project_slug,
        :source_commit, :source_context, :applies_to, :tags
      ]
      change set_attribute(:status, :proposed)
    end

    create :propose do
      accept [
        :content, :category, :severity, :source_project_slug,
        :source_commit, :source_context, :applies_to, :tags
      ]
      change set_attribute(:status, :proposed)
    end

    update :update do
      primary? true
      accept [
        :content, :category, :severity, :source_project_slug,
        :source_commit, :source_context, :applies_to, :tags
      ]
    end

    update :approve do
      accept []
      change set_attribute(:status, :approved)
      change set_attribute(:approved_at, &DateTime.utc_now/0)
    end

    update :retire do
      accept [:retired_reason]
      change set_attribute(:status, :retired)
      change set_attribute(:retired_at, &DateTime.utc_now/0)
    end

    update :mark_linter do
      accept []
      change set_attribute(:status, :linter)
    end

    update :reset_to_proposed do
      accept []
      change set_attribute(:status, :proposed)
      change set_attribute(:approved_at, nil)
    end

    read :approved do
      filter expr(status == :approved)
    end

    read :proposed do
      filter expr(status == :proposed)
    end

    read :by_category do
      argument :category, :atom, allow_nil?: false
      filter expr(status == :approved and category == ^arg(:category))
    end

    read :for_project do
      argument :project_type, :string, allow_nil?: false
      filter expr(
        status == :approved and
        (contains(applies_to, "all") or contains(applies_to, ^arg(:project_type)))
      )
    end
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :content, :string do
      allow_nil? false
      public? true
      description "The actual rule text / instruction"
    end

    attribute :category, :atom do
      constraints one_of: [
        :architecture, :liveview, :ash, :heex, :css,
        :elixir, :testing, :deployment, :pubsub, :forms,
        :components, :routing, :security
      ]
      allow_nil? false
      public? true
    end

    attribute :severity, :atom do
      constraints one_of: [:must, :should, :prefer]
      default :should
      public? true
      description "How strongly this rule is enforced"
    end

    attribute :status, :atom do
      constraints one_of: [:proposed, :approved, :retired, :linter]
      default :proposed
      public? true
    end

    attribute :source_project_slug, :string do
      public? true
      description "Project slug where this rule was discovered (e.g. 'calvin')"
    end

    attribute :source_commit, :string do
      public? true
      description "Git SHA that proved this rule"
    end

    attribute :source_context, :string do
      public? true
      description "Why this rule exists — the incident or mistake that led to it"
    end

    attribute :applies_to, {:array, :string} do
      default ["all"]
      public? true
      description "Project types this applies to: all, ash, phoenix, liveview"
    end

    attribute :tags, {:array, :string} do
      default []
      public? true
      description "Freeform tags for grouping into skills"
    end

    attribute :retired_reason, :string do
      public? true
    end

    attribute :approved_at, :utc_datetime_usec do
      public? true
    end

    attribute :retired_at, :utc_datetime_usec do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  code_interface do
    define :create
    define :read
    define :update
    define :propose
    define :approve
    define :retire
    define :destroy
    define :approved
    define :proposed
    define :mark_linter
    define :reset_to_proposed
    define :by_id, get_by: [:id], action: :read
  end
end
