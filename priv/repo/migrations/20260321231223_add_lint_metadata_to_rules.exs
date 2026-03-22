defmodule Maestro.Repo.Migrations.AddLintMetadataToRules do
  use Ecto.Migration

  def up do
    alter table(:rules) do
      add :lint_pattern, :text
      add :lint_file_types, {:array, :text}, default: []
      add :lint_message, :text
      add :lint_exclude_paths, {:array, :text}, default: []
      add :lint_only_paths, {:array, :text}, default: []
    end
  end

  def down do
    alter table(:rules) do
      remove :lint_pattern
      remove :lint_file_types
      remove :lint_message
      remove :lint_exclude_paths
      remove :lint_only_paths
    end
  end
end
