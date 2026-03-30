defmodule Maestro.Ops.AuditPubSub do
  @moduledoc """
  PubSub notifier for Audit resources.

  Broadcasts on create/update so the audit LiveView auto-refreshes.
  """

  use Ash.Notifier

  @topic "audits"

  @spec topic() :: term()
  def topic, do: @topic

  @impl true
  @spec notify(struct()) :: term()
  def notify(%Ash.Notifier.Notification{resource: Maestro.Ops.Audit} = notification) do
    if Process.whereis(Maestro.PubSub) do
      Phoenix.PubSub.broadcast(
        Maestro.PubSub,
        @topic,
        {:audit_changed, notification.action.name, notification.data}
      )
    end

    :ok
  end
end
