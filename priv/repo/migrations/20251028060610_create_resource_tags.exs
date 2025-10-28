defmodule Maestro.Repo.Migrations.CreateResourceTags do
  use Ecto.Migration

  def change do
    create table(:resource_tags, primary_key: false) do
      add :resource_id, references(:resources, on_delete: :delete_all), null: false
      add :tag_id, references(:tags, on_delete: :delete_all), null: false

      timestamps(updated_at: false)
    end

    create unique_index(:resource_tags, [:resource_id, :tag_id])
    create index(:resource_tags, [:tag_id])
  end
end
