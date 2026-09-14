defmodule MaestroWeb.HealthControllerTest do
  use MaestroWeb.ConnCase, async: true

  test "reports application health without authentication", %{conn: conn} do
    conn = get(conn, "/healthz")
    assert response(conn, 200) == "ok"
  end
end
