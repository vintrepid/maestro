defmodule Maestro.Release do
  @moduledoc "Database release tasks for production releases."

  @app :maestro

  @spec migrate() :: :ok
  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn repo ->
          Ecto.Migrator.run(repo, :up, all: true)
          migrate_startup_registry(repo)
        end)
    end

    :ok
  end

  @spec rollback(module(), integer()) :: :ok
  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
    :ok
  end

  defp repos, do: Application.fetch_env!(@app, :ecto_repos)

  defp load_app do
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end

  defp migrate_startup_registry(repo) do
    # The host owns its legacy tasks. Consume the library's startup-registry
    # migration without applying its standalone task bootstrap schema.
    unless Code.ensure_loaded?(Maestro.Repo.Migrations.DevServerProjects) do
      :maestro_tool
      |> Application.app_dir("priv/repo/migrations/20260918112304_dev_server_projects.exs")
      |> Code.require_file()
    end

    Ecto.Migrator.run(
      repo,
      [{20_260_918_112_304, Maestro.Repo.Migrations.DevServerProjects}],
      :up,
      all: true
    )
  end
end
