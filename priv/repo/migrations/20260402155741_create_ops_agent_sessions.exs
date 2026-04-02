defmodule Maestro.Repo.Migrations.CreateOpsAgentSessions do
  @moduledoc """
  Creates ops_agent_sessions and agent_session_rules tables.
  """

  use Ecto.Migration

  def up do
    create table(:ops_agent_sessions, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :name, :text, null: false
      add :project_id, :text, null: false
      add :bundle, :text, null: false
      add :purpose, :text
      add :status, :text, default: "active"
      add :worktree_path, :text
      add :branch_name, :text
      add :completed_at, :utc_datetime_usec

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create table(:agent_session_rules, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :agent_session_id,
          references(:ops_agent_sessions,
            column: :id,
            name: "agent_session_rules_agent_session_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :rule_id,
          references(:rules,
            column: :id,
            name: "agent_session_rules_rule_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false
    end
  end

  def down do
    drop constraint(:agent_session_rules, "agent_session_rules_agent_session_id_fkey")
    drop constraint(:agent_session_rules, "agent_session_rules_rule_id_fkey")
    drop table(:agent_session_rules)
    drop table(:ops_agent_sessions)
  end
end
