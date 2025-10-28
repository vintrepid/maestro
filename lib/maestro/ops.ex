defmodule Maestro.Ops do
  use Ash.Domain, otp_app: :maestro

  resources do
    resource Maestro.Ops.Project
    resource Maestro.Ops.Task
  end

  import Ecto.Query
  alias Maestro.Repo
  alias Maestro.Ops.Project

  def list_projects do
    Repo.all(from p in Project, order_by: p.name)
  end

  def get_project_by_slug(slug) do
    Repo.get_by(Project, slug: slug)
  end

  def list_projects_query do
    from p in Project, order_by: p.name
  end
end
