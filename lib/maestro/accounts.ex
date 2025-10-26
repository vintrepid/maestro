defmodule Maestro.Accounts do
  use Ash.Domain, otp_app: :maestro, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Maestro.Accounts.Token
    resource Maestro.Accounts.User
  end
end
