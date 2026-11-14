defmodule Maestro.App do
  @moduledoc "Application-level operations callable via RPC during deploys."

  @spec deploying!() :: :ok | {:error, term()}
  def deploying! do
    Phoenix.PubSub.broadcast(
      Maestro.PubSub,
      "system:broadcast",
      {:system_flash, :info, "Deploying updates — back in about a minute"}
    )
  end
end
