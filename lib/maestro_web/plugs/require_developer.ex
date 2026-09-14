defmodule MaestroWeb.Plugs.RequireDeveloper do
  @moduledoc "Requires an authenticated user with Maestro developer access."

  import Plug.Conn
  import Phoenix.Controller

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    if Maestro.Accounts.DeveloperAccess.allowed?(conn.assigns[:current_user]) do
      conn
    else
      destination = if conn.assigns[:current_user], do: "/sign-out", else: "/sign-in"

      conn
      |> put_session(:return_to, current_path(conn))
      |> redirect(to: destination)
      |> halt()
    end
  end
end
