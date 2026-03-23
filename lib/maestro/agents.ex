defmodule Maestro.Agents do
  use Ash.Domain, otp_app: :maestro

  resources do
    resource Maestro.Agents.Agent
    resource Maestro.Agents.Session
    resource Maestro.Agents.Request
  end
end
