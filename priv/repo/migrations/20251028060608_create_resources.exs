defmodule Maestro.Repo.Migrations.CreateResources do
  use Ecto.Migration

  def change do
    create table(:resources) do
      add :title, :string, null: false
      add :description, :text
      add :resource_type, :string, null: false
      add :url, :text
      add :file_path, :text
      add :content, :text
      add :thumbnail_url, :text
      add :platform, :string
      add :metadata, :map, default: %{}
      add :owner_type, :string, null: false
      add :owner_id, :string, null: false

      timestamps()
    end

    create index(:resources, [:owner_type, :owner_id])
    create index(:resources, [:resource_type])
  end
end
