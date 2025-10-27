defmodule Maestro.Repo.Migrations.AddUserProfileFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :name, :string
      add :bio, :text
    end
  end
end
