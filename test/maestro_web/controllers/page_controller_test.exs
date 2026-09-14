defmodule MaestroWeb.PageControllerTest do
  use MaestroWeb.ConnCase

  import Phoenix.LiveViewTest

  test "GET / requires authentication", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/sign-in"
  end

  test "GET / accepts an authenticated developer", %{conn: conn} do
    user = Ash.Seed.seed!(Maestro.Accounts.User, %{email: "developer@example.com"})
    {:ok, token, _claims} = AshAuthentication.Jwt.token_for_user(user)
    signed_in_user = Ash.Resource.put_metadata(user, :token, token)

    conn =
      conn
      |> init_test_session(%{})
      |> AshAuthentication.Phoenix.Plug.store_in_session(signed_in_user)

    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "#maestro-home")
  end
end
