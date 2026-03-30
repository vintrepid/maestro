defmodule Maestro.Repo.Migrations.DropUniqueWebPortIndex do
  use Ecto.Migration

  def change do
    drop_if_exists unique_index(:projects, [:web_port], name: "projects_unique_web_port_index")
  end
end
