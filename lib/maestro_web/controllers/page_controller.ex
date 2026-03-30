defmodule MaestroWeb.PageController do
  @moduledoc false
  use MaestroWeb, :controller

  @spec home(Plug.Conn.t(), map()) :: term()
  def home(conn, _params) do
    render(conn, :home)
  end
end
