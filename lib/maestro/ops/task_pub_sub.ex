defmodule Maestro.Ops.TaskPubSub do
  @moduledoc """
  PubSub notifier for the Task resource.

  Broadcasts on create/update so any LiveView subscribed to the task topic
  auto-refreshes without manual reload. Follows the rule:
  "Every resource that participates in multi-user pages MUST have notifiers."
  """

  use Ash.Notifier

  @topic "tasks"

  def topic, do: @topic

  @impl true
  def notify(%Ash.Notifier.Notification{resource: Maestro.Ops.Task} = notification) do
    Phoenix.PubSub.broadcast(
      Maestro.PubSub,
      @topic,
      {:task_changed, notification.action.name, notification.data}
    )

    :ok
  end
end
