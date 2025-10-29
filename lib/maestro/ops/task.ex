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

    attribute :notes, :string

    attribute :due_at, :utc_datetime_usec

    attribute :completed_at, :utc_datetime_usec

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

  calculations do
    calculate :display_name, :string, expr(
      cond do
        not is_nil(title) and entity_type == "Project" ->
          fragment("? || ' - ' || (SELECT name FROM projects WHERE id = CAST(? AS uuid))", title, entity_id)
        not is_nil(title) and entity_type == "Task" ->
          fragment("? || ' - ' || (SELECT title FROM tasks WHERE id = CAST(? AS integer))", title, entity_id)
        true -> title
      end
    )
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:title, :description, :notes, :due_at, :completed_at, :task_type, :status, :entity_type, :entity_id]
    end

    update :update do
      accept [:title, :description, :notes, :due_at, :completed_at, :task_type, :status, :entity_type, :entity_id]
    end

    update :mark_complete do
      accept []
      change set_attribute(:status, :done)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :mark_complete
    define :destroy
    define :by_id, get_by: [:id], action: :read
  end
end
