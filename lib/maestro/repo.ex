defmodule Maestro.Repo do
  @moduledoc false
  use AshPostgres.Repo,
    otp_app: :maestro

  @impl true
  @spec installed_extensions() :: term()
  def installed_extensions do
    # Add extensions here, and the migration generator will install them.
    ["ash-functions", "citext", AshMoney.AshPostgresExtension]
  end

  # Don't open unnecessary transactions
  # will default to `false` in 4.0
  @impl true
  @spec prefer_transaction?() :: term()
  def prefer_transaction? do
    false
  end

  @impl true
  @spec min_pg_version() :: term()
  def min_pg_version do
    %Version{major: 14, minor: 19, patch: 0}
  end
end
