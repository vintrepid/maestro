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
        :content, :content_hash, :category, :severity, :source_project_slug,
        :source_commit, :source_context, :applies_to, :tags,
        :library_id, :rule_source_id
      ]
      change set_attribute(:status, :proposed)
      change Maestro.Ops.Rule.Changes.ComputeContentHash
    end

    create :propose do
      accept [
        :content, :content_hash, :category, :severity, :source_project_slug,
        :source_commit, :source_context, :applies_to, :tags,
        :library_id, :rule_source_id
      ]
      change set_attribute(:status, :proposed)
      change Maestro.Ops.Rule.Changes.ComputeContentHash
    end

    update :update do
      primary? true
      accept [
        :content, :category, :severity, :source_project_slug,
        :source_commit, :source_context, :applies_to, :tags,
        :library_id, :rule_source_id, :content_hash,
        :fix_type, :fix_template, :fix_target, :fix_search,
        :notes
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
      accept [:lint_pattern, :lint_file_types, :lint_message, :lint_exclude_paths, :lint_only_paths]
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

    read :linter do
      filter expr(status == :linter and not is_nil(lint_pattern))
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

    attribute :content_hash, :string do
      public? true
      description "SHA256 of normalized content for deduplication"
    end

    attribute :retired_reason, :string do
      public? true
    end

    attribute :notes, :string do
      public? true
      description "Curator notes — freeform comments during review"
    end

    attribute :lint_pattern, :string do
      public? true
      description "Regex pattern for linter checks (stored as string, compiled at runtime)"
    end

    attribute :lint_file_types, {:array, :string} do
      default []
      public? true
      description "File types to check: ex, heex"
    end

    attribute :lint_message, :string do
      public? true
      description "Message shown when the lint pattern matches"
    end

    attribute :lint_exclude_paths, {:array, :string} do
      default []
      public? true
      description "Path substrings to exclude from this check"
    end

    attribute :lint_only_paths, {:array, :string} do
      default []
      public? true
      description "If non-empty, only check files matching these path substrings"
    end

    attribute :fix_type, :atom do
      constraints one_of: [
        :add_callback,       # Add a function/callback if missing (e.g. handle_params)
        :add_to_mount,       # Add code to mount function (e.g. PubSub subscribe)
        :extract_css,        # Move inline Tailwind utilities to semantic CSS
        :replace_pattern,    # Replace one code pattern with another
        :remove_pattern,     # Remove matching code (e.g. embedded <script>)
        :wrap_pattern        # Wrap existing code with additional code
      ]
      public? true
      description "Strategy for auto-fixing violations of this rule"
    end

    attribute :fix_template, :string do
      public? true
      description "Fix content: the code to add, the replacement, or the CSS class name"
    end

    attribute :fix_target, :string do
      public? true
      description "Where to apply: callback name, mount, template, css, or a regex match target"
    end

    attribute :fix_search, :string do
      public? true
      description "Regex pattern to find what needs fixing (for replace/remove/wrap)"
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

  relationships do
    belongs_to :library, Maestro.Ops.Library do
      public? true
      allow_nil? true
    end

    belongs_to :rule_source, Maestro.Ops.RuleSource do
      public? true
      allow_nil? true
    end
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
    define :linter
    define :by_content_hash, args: [:content_hash]
    define :by_id, get_by: [:id], action: :read
  end
end
