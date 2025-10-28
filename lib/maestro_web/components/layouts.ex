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
    current_project = try do
      Maestro.Ops.AppState.get_current_project()
    rescue
      _ -> nil
    end
    
    assigns = assign(assigns, :current_project, current_project)
    
    ~H"""
    <div class="drawer">
      <input id="main-drawer" type="checkbox" class="drawer-toggle" />
      <div class="drawer-content flex flex-col">
        <div class="navbar bg-base-200 sticky top-0 z-50 shadow-md">
          <div class="navbar-start">
            <%= if @current_project do %>
              <a href={~p"/projects/#{@current_project.slug}"} class="btn btn-ghost text-xl">
                🎼 {@current_project.name}
              </a>
            <% else %>
              <a href="/" class="btn btn-ghost text-xl">🎼 Maestro</a>
            <% end %>
          </div>
          <div class="navbar-center gap-2">
            <a href="/projects" class="btn btn-ghost">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
              </svg>
              Projects
            </a>
            <a href="/tasks" class="btn btn-ghost">
              <.icon name="hero-check-circle" class="w-5 h-5" />
              Tasks
            </a>
            <a href="/resources" class="btn btn-ghost">
              <.icon name="hero-bookmark" class="w-5 h-5" />
              Resources
            </a>
            <a href="/concepts" class="btn btn-ghost">
              <.icon name="hero-square-3-stack-3d" class="w-5 h-5" />
              Concepts
            </a>
          </div>
          <div class="navbar-end gap-2">
            <.git_dropdown />
            <.user_menu current_user={@current_user} />
          </div>
        </div>

        <main class="container mx-auto px-4 py-2 max-w-7xl flex-1">
          {render_slot(@inner_block)}
        </main>
      </div>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  def git_dropdown(assigns) do
    ~H"""
    <div class="dropdown dropdown-end" id="git-dropdown" data-project-path="">
      <div tabindex="0" role="button" class="btn btn-ghost btn-sm gap-2" id="git-dropdown-button" onclick="window.loadGitInfo()">
        <.icon name="hero-code-bracket" class="w-4 h-4" />
        <span class="font-mono text-xs" id="git-branch-label">git</span>
        <span id="git-commits-ahead"></span>
        <span id="git-commits-behind"></span>
      </div>
      <ul tabindex="0" class="dropdown-content z-[1] menu p-2 shadow-lg bg-base-100 rounded-box w-64" id="git-dropdown-menu" style="display: none;">
        <li class="menu-title">Current Branch</li>
        <li class="px-4 py-2">
          <span class="font-mono text-sm" id="git-current-branch"></span>
        </li>
        <div id="git-other-branches"></div>
      </ul>
    </div>
    
    <script>
      window.loadGitInfo = function() {
        if (window.gitInfoLoaded) {
          document.getElementById('git-dropdown-menu').style.display = 'block';
          return;
        }
        
        const dropdown = document.getElementById('git-dropdown');
        const projectPath = dropdown.dataset.projectPath;
        const url = projectPath ? `/api/git/info?project_path=${encodeURIComponent(projectPath)}` : '/api/git/info';
        
        fetch(url)
          .then(r => r.json())
          .then(data => {
            document.getElementById('git-branch-label').textContent = data.current_branch;
            document.getElementById('git-current-branch').textContent = data.current_branch;
            
            if (data.commits_ahead) {
              document.getElementById('git-commits-ahead').innerHTML = `<span class="badge badge-xs badge-warning">+${data.commits_ahead}</span>`;
            }
            
            if (data.commits_behind) {
              document.getElementById('git-commits-behind').innerHTML = `<span class="badge badge-xs badge-error">-${data.commits_behind}</span>`;
            }
            
            if (data.other_branches && data.other_branches.length > 0) {
              const branchesHTML = data.other_branches.map(b => `
                <li>
                  <div class="flex items-center justify-between">
                    <span class="font-mono text-xs">${b.branch}</span>
                    <div class="flex gap-1">
                      ${b.ahead ? `<span class="badge badge-xs badge-warning">+${b.ahead}</span>` : ''}
                      ${b.behind ? `<span class="badge badge-xs badge-error">-${b.behind}</span>` : ''}
                    </div>
                  </div>
                </li>
              `).join('');
              
              document.getElementById('git-other-branches').innerHTML = `
                <li class="menu-title mt-2">Other Branches</li>
                ${branchesHTML}
              `;
            }
            
            document.getElementById('git-dropdown-menu').style.display = 'block';
            window.gitInfoLoaded = true;
          })
          .catch(err => console.error('Failed to load git info:', err));
      };
      
      document.addEventListener('click', function(e) {
        const dropdown = document.getElementById('git-dropdown');
        if (dropdown && !dropdown.contains(e.target)) {
          document.getElementById('git-dropdown-menu').style.display = 'none';
        }
      });
    </script>
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
          <li>
            <details>
              <summary><.icon name="hero-cog-6-tooth" class="w-4 h-4" /> Settings</summary>
              <ul>
                <li><a href="/settings/hotkeys"><.icon name="hero-command-line" class="w-4 h-4" /> Hotkeys</a></li>
                <li><a href="/settings/aliases"><.icon name="hero-chat-bubble-left-right" class="w-4 h-4" /> Aliases</a></li>
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
            </details>
          </li>
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
