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
      Maestro.Ops.AppState,
      MaestroWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :maestro]},
      # Enable FunWithFlags PubSub AFTER PubSub is started.
      # This avoids the race condition where FWF tries to subscribe before PubSub is ready.
      {Task, fn -> enable_fwf_pubsub() end}
    ]

    opts = [strategy: :one_for_one, name: Maestro.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp enable_fwf_pubsub do
    # Give PubSub a moment to fully initialize
    Process.sleep(500)

    if Process.whereis(Maestro.PubSub) do
      Application.put_env(:fun_with_flags, :cache_bust_notifications,
        enabled: true,
        adapter: FunWithFlags.Notifications.PhoenixPubSub,
        client: Maestro.PubSub
      )
    end
  end

  @impl true
  def config_change(changed, _new, removed) do
    MaestroWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
