defmodule MaestroWeb.DepsLiveTest do
  use MaestroWeb.ConnCase

  import Phoenix.LiveViewTest

  test "dependency maintenance requires developer authentication", %{conn: conn} do
    conn = get(conn, ~p"/admin/deps")
    assert redirected_to(conn) == ~p"/sign-in"
  end

  test "a developer sees the shared inventory and can configure a dry inspection", %{conn: conn} do
    enable_local_tools()
    {:ok, view, _html} = live(sign_in(conn), ~p"/admin/deps")
    render_async(view, 5_000)

    assert has_element?(view, "h1", "Maestro dependencies")
    assert has_element?(view, "[data-testid='dependency-app-state']", "maestro")
    assert has_element?(view, "#dependency-run-options")

    view
    |> form("#dependency-run-options", update: %{scope: "project", mode: "inspect"})
    |> render_change()

    assert has_element?(view, "[data-testid='dependency-command']", "--project --dry-run")
  end

  test "checkout tools are unavailable outside local development", %{conn: conn} do
    previous = Application.get_env(:maestro, :dev_routes)
    Application.put_env(:maestro, :dev_routes, false)
    on_exit(fn -> restore_local_tools(previous) end)

    assert {:error, {:redirect, %{to: "/"}}} = live(sign_in(conn), ~p"/admin/deps")
  end

  defp enable_local_tools do
    previous = Application.get_env(:maestro, :dev_routes)
    Application.put_env(:maestro, :dev_routes, true)
    on_exit(fn -> restore_local_tools(previous) end)
  end

  defp restore_local_tools(nil), do: Application.delete_env(:maestro, :dev_routes)
  defp restore_local_tools(value), do: Application.put_env(:maestro, :dev_routes, value)

  defp sign_in(conn) do
    user = Ash.Seed.seed!(Maestro.Accounts.User, %{email: "developer@example.com"})
    {:ok, token, _claims} = AshAuthentication.Jwt.token_for_user(user)

    conn
    |> init_test_session(%{})
    |> AshAuthentication.Phoenix.Plug.store_in_session(
      Ash.Resource.put_metadata(user, :token, token)
    )
  end
end
