defmodule MaestroWeb.ProfileLive do
  use MaestroWeb, :live_view

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
      <div class="min-h-screen bg-gradient-to-br from-base-200 to-base-300 py-12 px-4 sm:px-6 lg:px-8">
        <div class="max-w-2xl mx-auto">
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title text-3xl font-bold mb-6">
                <.icon name="hero-user-circle" class="w-8 h-8 text-primary" />
                Edit Profile
              </h2>

              <.form
                for={@form}
                id="profile-form"
                phx-change="validate"
                phx-submit="save"
                class="space-y-6"
              >
                <div class="form-control">
                  <label class="label">
                    <span class="label-text font-semibold">Email</span>
                  </label>
                  <.input
                    field={@form[:email]}
                    type="email"
                    placeholder="your.email@example.com"
                    class="input input-bordered w-full"
                    readonly
                  />
                  <label class="label">
                    <span class="label-text-alt text-base-content/60">
                      Email cannot be changed
                    </span>
                  </label>
                </div>

                <div class="form-control">
                  <label class="label">
                    <span class="label-text font-semibold">Full Name</span>
                  </label>
                  <.input
                    field={@form[:name]}
                    type="text"
                    placeholder="John Doe"
                    class="input input-bordered w-full"
                  />
                </div>

                <div class="form-control">
                  <label class="label">
                    <span class="label-text font-semibold">Bio</span>
                  </label>
                  <.input
                    field={@form[:bio]}
                    type="textarea"
                    placeholder="Tell us about yourself..."
                    class="textarea textarea-bordered w-full h-32"
                  />
                </div>

                <div class="divider"></div>

                <div class="flex gap-4 justify-end">
                  <.link navigate={~p"/"} class="btn btn-ghost">
                    Cancel
                  </.link>
                  <button type="submit" class="btn btn-primary">
                    <.icon name="hero-check" class="w-5 h-5" />
                    Save Changes
                  </button>
                </div>
              </.form>
            </div>
          </div>

          <div class="mt-6 text-center">
            <.link navigate={~p"/"} class="link link-hover text-base-content/60">
              ← Back to Dashboard
            </.link>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
