defmodule MaestroWeb.ProfileLive do
  use MaestroWeb, :live_view

  alias MaestroWeb.Components.GitWidget
  alias MaestroWeb.Components.GuidelinesViewer
  import MaestroWeb.Live.Helpers.FileOpener

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns[:current_user] do
      user = socket.assigns.current_user
      form = AshPhoenix.Form.for_update(user, :update_profile, domain: Maestro.Accounts)

      {:ok,
       socket
       |> assign(:page_title, "Edit Profile")
       |> assign(:user, user)
       |> assign(:form, to_form(form))}
    else
      {:ok, push_navigate(socket, to: ~p"/sign-in")}
    end
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("open_file", %{"path" => path}, socket) do
    open_file(path)
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(:user, user)
         |> put_flash(:info, "Profile updated successfully")
         |> push_navigate(to: ~p"/profile")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="container mx-auto p-6">
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div class="lg:col-span-1">
            <GuidelinesViewer.guidelines_viewer />
          </div>

          <div class="lg:col-span-2">
            <.card>
              <h2 class="card-title">
                <.icon name="hero-user-circle" class="w-6 h-6" />
                Edit Profile
              </h2>

              <.form for={@form} id="profile-form" phx-change="validate" phx-submit="save">
                <.input field={@form[:email]} label="Email" type="email" readonly />
                <p class="text-sm text-base-content/60 mt-1">Email cannot be changed</p>

                <.input field={@form[:name]} label="Full Name" type="text" />

                <.input field={@form[:bio]} label="Bio" type="textarea" rows="4" />

                <.input field={@form[:editor_command]} label="Editor Command" type="text" 
                  placeholder="code (for VSCodium/VSCode)" />
                <p class="text-sm text-base-content/60 mt-1">
                  Command to open projects. Use 'code' for VSCodium, 'cursor' for Cursor, etc.
                </p>

                <div class="divider"></div>

                <div class="flex gap-2 justify-end">
                  <.link navigate={~p"/"} class="btn btn-ghost">Cancel</.link>
                  <button type="submit" class="btn btn-primary">
                    <.icon name="hero-check" class="w-5 h-5" />
                    Save Changes
                  </button>
                </div>
              </.form>
            </.card>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
