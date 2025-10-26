defmodule Maestro.Repo.Migrations.CreateTailwindClassUsage do
  use Ecto.Migration

  def change do
    create table(:tailwind_class_usage, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :class_name, :string, null: false
      add :category, :string
      add :description, :text
      add :file_path, :string, null: false
      add :line_number, :integer, null: false
      add :context, :text
      add :usage_count, :integer, default: 1
      add :analyzed_at, :utc_datetime
      
      timestamps()
    end
    
    create index(:tailwind_class_usage, [:class_name])
    create index(:tailwind_class_usage, [:category])
    create index(:tailwind_class_usage, [:file_path])
    create index(:tailwind_class_usage, [:analyzed_at])
  end
end
