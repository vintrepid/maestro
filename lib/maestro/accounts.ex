defmodule Maestro.Accounts do
  @moduledoc """
  Accounts domain — Ash resource registry.
  """
  use Ash.Domain, otp_app: :maestro, extensions: [AshAdmin.Domain, AshJsonApi.Domain]

  admin do
    show? true
  end

  json_api do
    authorize? false
  end

  resources do
    resource Maestro.Accounts.Token
    resource Maestro.Accounts.User
  end
end
