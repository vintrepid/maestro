defmodule Maestro.Repo.Migrations.CreateTagHierarchies do
  use Ecto.Migration

  def change do
    create table(:tag_hierarchies, primary_key: false) do
      add :parent_tag_id, references(:tags, on_delete: :delete_all), null: false
      add :child_tag_id, references(:tags, on_delete: :delete_all), null: false

      timestamps(updated_at: false)
    end

    create unique_index(:tag_hierarchies, [:parent_tag_id, :child_tag_id])
    create index(:tag_hierarchies, [:child_tag_id])
  end
end
