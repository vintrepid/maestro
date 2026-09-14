defmodule MaestroWeb.HealthController do
  @moduledoc false

  use MaestroWeb, :controller

  @spec check(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def check(conn, _params), do: send_resp(conn, 200, "ok")
end
