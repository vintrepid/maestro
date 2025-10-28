defmodule Maestro.Repo.Migrations.CreateTags do
  use Ecto.Migration

  def change do
    create table(:tags) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :color, :string
      add :owner_type, :string, null: false
      add :owner_id, :string, null: false

      timestamps()
    end

    create unique_index(:tags, [:slug, :owner_type, :owner_id])
    create index(:tags, [:owner_type, :owner_id])
  end
end
