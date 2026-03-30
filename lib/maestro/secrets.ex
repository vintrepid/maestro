defmodule Maestro.Secrets do
  @moduledoc false
  use AshAuthentication.Secret

  @spec secret_for(any(), any(), keyword(), any()) :: term()
  def secret_for(
        [:authentication, :tokens, :signing_secret],
        Maestro.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:maestro, :token_signing_secret)
  end
end
