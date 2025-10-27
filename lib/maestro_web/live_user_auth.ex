defmodule MaestroWeb.LiveUserAuth do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """

  import Phoenix.Component
  use MaestroWeb, :verified_routes

  defp get_current_app do
    otp_app = Application.get_application(__MODULE__)
    Application.get_env(otp_app, :current_app) || 
      (otp_app |> to_string() |> String.capitalize()) ||
      "Your App"
  end

  # This is used for nested liveviews to fetch the current user.
  # To use, place the following at the top of that liveview:
  # on_mount {MaestroWeb.LiveUserAuth, :current_user}
  def on_mount(:current_user, _params, session, socket) do
    socket = AshAuthentication.Phoenix.LiveSession.assign_new_resources(socket, session)
    current_app = get_current_app()
    {:cont, assign(socket, :current_app, current_app)}
  end

  def on_mount(:load_current_user, _params, _session, socket) do
    require Ash.Query
    
    user = Maestro.Accounts.User
      |> Ash.Query.limit(1)
      |> Ash.Query.select([:id, :email, :name, :bio])
      |> Ash.read_one!()
    
    current_app = get_current_app()
    
    {:cont, socket |> assign(:current_user, user) |> assign(:current_app, current_app)}
  end

  def on_mount(:live_user_optional, _params, _session, socket) do
    current_app = get_current_app()
    
    if socket.assigns[:current_user] do
      {:cont, assign(socket, :current_app, current_app)}
    else
      {:cont, socket |> assign(:current_user, nil) |> assign(:current_app, current_app)}
    end
  end

  def on_mount(:live_user_required, _params, _session, socket) do
    current_app = get_current_app()
    
    if socket.assigns[:current_user] do
      {:cont, assign(socket, :current_app, current_app)}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:live_no_user, _params, _session, socket) do
    current_app = get_current_app()
    
    if socket.assigns[:current_user] do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    else
      {:cont, socket |> assign(:current_user, nil) |> assign(:current_app, current_app)}
    end
  end
end
