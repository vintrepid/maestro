defmodule Maestro.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MaestroWeb.Telemetry,
      Maestro.Repo,
      {DNSCluster, query: Application.get_env(:maestro, :dns_cluster_query) || :ignore},
      {Oban,
       AshOban.config(
         Application.fetch_env!(:maestro, :ash_domains),
         Application.fetch_env!(:maestro, Oban)
       )},
      {Phoenix.PubSub, name: Maestro.PubSub},
      Maestro.Ops.ProjectMonitor,
      MaestroWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :maestro]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Maestro.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MaestroWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
