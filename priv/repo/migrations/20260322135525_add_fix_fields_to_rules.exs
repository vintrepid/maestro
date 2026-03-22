defmodule Maestro.Repo.Migrations.AddFixFieldsToRules do
  use Ecto.Migration

  def change do
    alter table(:rules) do
      add :fix_type, :string
      add :fix_template, :text
      add :fix_target, :string
      add :fix_search, :string
    end
  end
end
