defmodule MaestroWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use MaestroWeb, :html

  embed_templates "layouts/*"

  @doc """
  Renders your app layout.
  """
  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  attr :current_user, :map, default: nil
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="drawer">
      <input id="main-drawer" type="checkbox" class="drawer-toggle" />
      <div class="drawer-content">
        <div class="navbar bg-base-200">
          <div class="navbar-brand">
            <a href="/" class="brand-link">🎼 Maestro</a>
          </div>
          <div class="navbar-actions">
            <.user_menu current_user={@current_user} />
            <.admin_menu />
          </div>
        </div>

        <main class="container mx-auto px-4 py-2 max-w-7xl">
          {render_slot(@inner_block)}
        </main>
      </div>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  def admin_menu(assigns) do
    ~H"""
    <div class="dropdown dropdown-end">
      <div tabindex="0" role="button" class="admin-menu-button">
        <.icon name="hero-cog-6-tooth" class="admin-menu-icon" />
      </div>
      <ul tabindex="0" class="dropdown-content z-[1] menu p-2 shadow-lg bg-base-100 rounded-box w-52">
        <li class="menu-title">Tools</li>
        <li><a href="/admin/tailwind-analysis">Tailwind Analysis</a></li>
        <li><a href="/admin/page-inventory">Page Inventory</a></li>
        <li><a href="/admin/component-replacement">Component Replacement</a></li>
        <li class="menu-title">Theme</li>
        <li>
          <button phx-click={set_theme("light")}>
            ☀️ Light
          </button>
        </li>
        <li>
          <button phx-click={set_theme("dark")}>
            🌙 Dark
          </button>
        </li>
        <li>
          <button phx-click={set_theme("both")}>
            ✨ Both
          </button>
        </li>
      </ul>
    </div>
    """
  end

  attr :current_user, :map, default: nil

  def user_menu(assigns) do
    ~H"""
    <%= if @current_user do %>
      <div class="dropdown dropdown-end mr-2">
        <div tabindex="0" role="button" class="btn btn-ghost btn-circle avatar">
          <div class="w-10 rounded-full bg-primary text-primary-content flex items-center justify-center">
            <%= if @current_user.name do %>
              <span class="text-lg font-semibold">
                {String.first(@current_user.name) |> String.upcase()}
              </span>
            <% else %>
              <.icon name="hero-user" class="w-6 h-6" />
            <% end %>
          </div>
        </div>
        <ul tabindex="0" class="dropdown-content z-[1] menu p-2 shadow-lg bg-base-100 rounded-box w-52">
          <li class="menu-title">
            <span class="truncate">{@current_user.email}</span>
          </li>
          <li><a href="/profile"><.icon name="hero-user" class="w-4 h-4" /> Profile</a></li>
          <li><a href="/sign-out"><.icon name="hero-arrow-right-on-rectangle" class="w-4 h-4" /> Sign Out</a></li>
        </ul>
      </div>
    <% else %>
      <a href="/sign-in" class="btn btn-ghost btn-sm mr-2">
        Sign In
      </a>
    <% end %>
    """
  end

  def theme_selector(assigns) do
    ~H"""
    <div class="join">
      <button
        class="btn btn-sm join-item"
        phx-click={set_theme("light")}
      >
        ☀️ Light
      </button>
      <button
        class="btn btn-sm join-item"
        phx-click={set_theme("dark")}
      >
        🌙 Dark
      </button>
      <button
        class="btn btn-sm join-item"
        phx-click={set_theme("both")}
      >
        ✨ Both
      </button>
    </div>
    """
  end

  defp set_theme(theme) do
    JS.push("set_theme", value: %{theme: theme})
  end

  @doc """
  Shows the flash group with standard titles and content.
  """
  attr :flash, :map, required: true
  attr :id, :string, default: "flash-group"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="flash-spinner" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="flash-spinner" />
      </.flash>
    </div>
    """
  end
end
