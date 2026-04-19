defmodule Maestro.Agents do
  @moduledoc """
  Agents domain — Ash resource registry.
  """
  use Ash.Domain, otp_app: :maestro, extensions: [AshJsonApi.Domain]

  json_api do
    authorize? true
  end

  resources do
    resource Maestro.Agents.Agent
    resource Maestro.Agents.Session
    resource Maestro.Agents.Request
  end
end
