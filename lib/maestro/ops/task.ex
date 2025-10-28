defmodule Maestro.Ops.Task do
  use Ash.Resource,
    domain: Maestro.Ops,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "tasks"
    repo Maestro.Repo
  end

  attributes do
    integer_primary_key :id

    attribute :title, :string do
      allow_nil? false
    end

    attribute :description, :string

    attribute :due_at, :utc_datetime_usec

    attribute :task_type, :atom do
      constraints one_of: [:feature, :bug, :refactor, :documentation, :other]
      default :feature
    end

    attribute :status, :atom do
      constraints one_of: [:todo, :in_progress, :done, :blocked]
      default :todo
    end

    attribute :entity_type, :string do
      allow_nil? false
    end

    attribute :entity_id, :string do
      allow_nil? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:title, :description, :due_at, :task_type, :status, :entity_type, :entity_id]
    end

    update :update do
      accept [:title, :description, :due_at, :task_type, :status]
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :by_id, get_by: [:id], action: :read
  end
end
