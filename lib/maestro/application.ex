defmodule Maestro.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MaestroWeb.Telemetry,
      Maestro.Repo,
      {Phoenix.PubSub, name: Maestro.PubSub},
      {DNSCluster, query: Application.get_env(:maestro, :dns_cluster_query) || :ignore},
      {Oban,
       AshOban.config(
         Application.fetch_env!(:maestro, :ash_domains),
         Application.fetch_env!(:maestro, Oban)
       )},
      Maestro.Ops.ProjectMonitor,
      MaestroWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :maestro]}
    ]

    opts = [strategy: :one_for_one, name: Maestro.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    MaestroWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
