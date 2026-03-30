defmodule Maestro.Ops.Skill do
  @moduledoc """
  Skill resource.
  """
  use Ash.Resource,
    otp_app: :maestro,
    domain: Maestro.Ops,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "skills"
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

      accept [
        :name,
        :description,
        :skill_path,
        :managed_by,
        :library_names,
        :reference_files,
        :last_synced_at
      ]

      upsert? true
      upsert_identity :unique_name

      upsert_fields [
        :description,
        :skill_path,
        :managed_by,
        :library_names,
        :reference_files,
        :last_synced_at
      ]
    end

    update :update do
      primary? true

      accept [
        :description,
        :skill_path,
        :managed_by,
        :library_names,
        :reference_files,
        :last_synced_at
      ]
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
      description "Skill name (e.g. ash-framework, phoenix-liveview)"
    end

    attribute :description, :string do
      public? true
      description "Skill description from SKILL.md frontmatter"
    end

    attribute :skill_path, :string do
      public? true
      description "Path to skill directory (e.g. .claude/skills/ash-framework)"
    end

    attribute :managed_by, :string do
      public? true
      description "Who manages this skill: usage-rules or manual"
    end

    attribute :library_names, {:array, :string} do
      default []
      public? true
      description "Libraries that contribute to this skill"
    end

    attribute :reference_files, {:array, :string} do
      default []
      public? true
      description "Reference markdown files in this skill"
    end

    attribute :last_synced_at, :utc_datetime_usec do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_name, [:name]
  end
end
