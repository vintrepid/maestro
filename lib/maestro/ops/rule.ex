defmodule Maestro.Ops.Rule do
  @moduledoc """
  Rule resource.
  """
  use Ash.Resource,
    otp_app: :maestro,
    domain: Maestro.Ops,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "rules"
    repo Maestro.Repo
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
    define :mark_anti_pattern
    define :reset_to_proposed
    define :linter
    define :by_content_hash, args: [:content_hash]
    define :by_id, get_by: [:id], action: :read
    define :by_bundle, args: [:bundle]
    define :supersede
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :content,
        :content_hash,
        :category,
        :severity,
        :source_project_slug,
        :source_commit,
        :source_context,
        :source_type,
        :source_agent_session_id,
        :applies_to,
        :tags,
        :library_id,
        :rule_source_id
      ]

      change set_attribute(:status, :proposed)
      change Maestro.Ops.Rule.Changes.ComputeContentHash
    end

    create :propose do
      accept [
        :content,
        :content_hash,
        :category,
        :severity,
        :source_project_slug,
        :source_commit,
        :source_context,
        :source_type,
        :source_agent_session_id,
        :applies_to,
        :tags,
        :library_id,
        :rule_source_id
      ]

      change set_attribute(:status, :proposed)
      change Maestro.Ops.Rule.Changes.ComputeContentHash
    end

    update :update do
      primary? true

      accept [
        :content,
        :category,
        :severity,
        :source_project_slug,
        :source_commit,
        :source_context,
        :source_type,
        :source_agent_session_id,
        :applies_to,
        :tags,
        :library_id,
        :rule_source_id,
        :content_hash,
        :fix_type,
        :fix_template,
        :fix_target,
        :fix_search,
        :notes,
        :priority,
        :bundle,
        :superseded_by_id
      ]
    end

    update :supersede do
      accept []
      require_atomic? false

      argument :superseded_by_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:superseded_by_id, arg(:superseded_by_id))
      change set_attribute(:status, :retired)
      change set_attribute(:retired_at, &DateTime.utc_now/0)
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
      accept [
        :lint_config,
        :lint_pattern,
        :lint_file_types,
        :lint_message,
        :lint_exclude_paths,
        :lint_only_paths
      ]

      change set_attribute(:status, :linter)
    end

    update :mark_anti_pattern do
      accept []
      change set_attribute(:status, :anti_pattern)
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

    read :linter do
      filter expr(status == :linter and (not is_nil(lint_pattern) or not is_nil(lint_config)))
    end

    read :by_category do
      argument :category, :atom, allow_nil?: false
      filter expr(status == :approved and category == ^arg(:category))
    end

    read :by_content_hash do
      argument :content_hash, :string, allow_nil?: false
      filter expr(content_hash == ^arg(:content_hash))
    end

    read :for_project do
      argument :project_type, :string, allow_nil?: false

      filter expr(
               status == :approved and
                 (contains(applies_to, "all") or contains(applies_to, ^arg(:project_type)))
             )
    end

    read :by_bundle do
      argument :bundle, :atom, allow_nil?: false
      filter expr(status == :approved and (bundle == ^arg(:bundle) or bundle == :universal))
      prepare build(sort: [priority: :desc, severity: :asc])
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
                    :architecture,
                    :liveview,
                    :ash,
                    :heex,
                    :css,
                    :elixir,
                    :testing,
                    :deployment,
                    :pubsub,
                    :forms,
                    :components,
                    :routing,
                    :security
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
      constraints one_of: [:proposed, :approved, :retired, :linter, :anti_pattern]
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

    attribute :source_type, :atom do
      constraints one_of: [:library_file, :agent_session, :article, :manual, :consolidated]
      default :manual
      public? true
      description "How this rule was created/discovered"
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

    attribute :priority, :integer do
      default 50
      public? true
      description "1-100, higher = more important. Used for bundle sizing."
    end

    attribute :bundle, :atom do
      constraints one_of: [:universal, :ui, :model, :devops, :maestro]
      default :universal
      public? true
      description "Which agent bundle this rule belongs to"
    end

    attribute :content_hash, :string do
      public? true
      description "SHA256 of normalized content for deduplication"
    end

    attribute :superseded_by_id, :uuid do
      public? true
      allow_nil? true
      description "ID of the rule that supersedes/replaces this one"
    end

    attribute :retired_reason, :string do
      public? true
    end

    attribute :notes, :string do
      public? true
      description "Curator notes — freeform comments during review"
    end

    attribute :lint_config, Maestro.Ops.Rule.LintConfig do
      public? true
      description "Linter configuration (pattern, file types, paths)"
    end

    attribute :fix_config, Maestro.Ops.Rule.FixConfig do
      public? true
      description "Auto-fix configuration (strategy, template, target)"
    end

    # Deprecated: kept for migration compatibility, will be removed
    attribute :lint_pattern, :string, public?: true
    attribute :lint_file_types, {:array, :string}, default: [], public?: true
    attribute :lint_message, :string, public?: true
    attribute :lint_exclude_paths, {:array, :string}, default: [], public?: true
    attribute :lint_only_paths, {:array, :string}, default: [], public?: true

    attribute :fix_type, :atom do
      constraints one_of: [
                    :add_callback,
                    :add_to_mount,
                    :add_spec,
                    :extract_css,
                    :replace_pattern,
                    :remove_pattern,
                    :wrap_pattern
                  ]

      public? true
    end

    attribute :fix_template, :string, public?: true
    attribute :fix_target, :string, public?: true
    attribute :fix_search, :string, public?: true

    attribute :approved_at, :utc_datetime_usec do
      public? true
    end

    attribute :retired_at, :utc_datetime_usec do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :library, Maestro.Ops.Library do
      public? true
      allow_nil? true
    end

    belongs_to :rule_source, Maestro.Ops.RuleSource do
      public? true
      allow_nil? true
    end

    belongs_to :source_agent_session, Maestro.Ops.AgentSession do
      public? true
      allow_nil? true
      description "The agent session that originally produced this rule (if applicable)"
    end

    belongs_to :superseded_by, Maestro.Ops.Rule do
      public? true
      allow_nil? true
      define_attribute? false
      destination_attribute :id
      source_attribute :superseded_by_id
    end

    has_many :supersedes, Maestro.Ops.Rule do
      public? true
      destination_attribute :superseded_by_id
    end
  end
end
