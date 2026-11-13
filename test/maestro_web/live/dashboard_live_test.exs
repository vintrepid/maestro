defmodule MaestroWeb.DashboardLiveTest do
  use MaestroWeb.ConnCase

  import Phoenix.LiveViewTest

  test "dashboard requires developer authentication", %{conn: conn} do
    conn = get(conn, ~p"/dashboard")

    assert redirected_to(conn) == ~p"/sign-in"
    assert get_session(conn, :return_to) == "/dashboard"
  end

  test "dashboard loads the projects view for an authenticated developer", %{conn: conn} do
    user = Ash.Seed.seed!(Maestro.Accounts.User, %{email: "developer@example.com"})
    {:ok, token, _claims} = AshAuthentication.Jwt.token_for_user(user)
    signed_in_user = Ash.Resource.put_metadata(user, :token, token)

    conn =
      conn
      |> init_test_session(%{})
      |> AshAuthentication.Phoenix.Plug.store_in_session(signed_in_user)

    {:ok, view, _html} = live(conn, ~p"/dashboard")

    assert has_element?(view, "h1", "Projects")
    assert has_element?(view, "a[href='/projects/new']", "New Project")
  end
end
