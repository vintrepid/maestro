defmodule MaestroWeb.ProfileLive do
  use MaestroWeb, :live_view

  alias MaestroWeb.Components.GitWidget
  alias MaestroWeb.Components.GuidelinesViewer

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns[:current_user] do
      user = socket.assigns.current_user
      form = AshPhoenix.Form.for_update(user, :update_profile, domain: Maestro.Accounts)

      project_guidelines = get_project_guidelines()
      fork_usage_rules = get_fork_usage_rules()
      package_usage_rules = get_package_usage_rules()
      agents_tree = get_agents_tree()
      current_branch = get_current_branch()
      commits_ahead = get_commits_ahead_of_master()
      commits_behind = get_commits_behind_master()
      other_branches = get_other_branches_ahead()

      {:ok,
       socket
       |> assign(:page_title, "Edit Profile")
       |> assign(:user, user)
       |> assign(:form, to_form(form))
       |> assign(:project_guidelines, project_guidelines)
       |> assign(:fork_usage_rules, fork_usage_rules)
       |> assign(:package_usage_rules, package_usage_rules)
       |> assign(:agents_tree, agents_tree)
       |> assign(:current_branch, current_branch)
       |> assign(:commits_ahead, commits_ahead)
       |> assign(:commits_behind, commits_behind)
       |> assign(:other_branches, other_branches)}
    else
      {:ok, push_navigate(socket, to: ~p"/sign-in")}
    end
  end

  defp get_project_guidelines do
    root_files = ["AGENTS.md", "REFACTORING_NOTES.md"]
    root_items = root_files
    |> Enum.map(fn file ->
      path = Path.join([File.cwd!(), file])
      if File.exists?(path) do
        %{name: "#{file} (project root)", type: :file, checked: true}
      end
    end)
    |> Enum.reject(&is_nil/1)

    project_path = Path.join([File.cwd!(), "agents", "project-specific", "maestro"])
    maestro_items = if File.exists?(project_path) do
      File.ls!(project_path)
      |> Enum.reject(&String.starts_with?(&1, "."))
      |> Enum.sort()
      |> Enum.map(&%{name: &1, type: :file, checked: true})
    else
      []
    end

    root_items ++ maestro_items
  end

  defp get_fork_usage_rules do
    forks_base = Path.expand("~/dev/forks")
    [
      {"live_table", "usage_rules.md"},
      {"css_linter", "README.md"}
    ]
    |> Enum.map(fn {fork, doc_file} ->
      doc_path = Path.join([forks_base, fork, doc_file])
      if File.exists?(doc_path) do
        %{name: "#{fork}/#{doc_file} (our fork)", type: :file, checked: true}
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp get_package_usage_rules do
    deps_path = Path.join([File.cwd!(), "deps"])
    if File.exists?(deps_path) do
      File.ls!(deps_path)
      |> Enum.map(fn dep ->
        usage_rules = Path.join([deps_path, dep, "usage-rules.md"])
        if File.exists?(usage_rules) do
          %{name: "#{dep}/usage-rules.md", type: :file, checked: true}
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(& &1.name)
    else
      []
    end
  end

  defp get_agents_tree do
    agents_path = Path.join([File.cwd!(), "agents"])
    if File.exists?(agents_path) do
      build_directory_tree(agents_path)
    else
      []
    end
  end

  defp get_current_branch do
    case System.cmd("git", ["branch", "--show-current"], stderr_to_stdout: true) do
      {branch, 0} -> String.trim(branch)
      _ -> "unknown"
    end
  end

  defp get_commits_ahead_of_master do
    case System.cmd("git", ["rev-list", "--count", "master..HEAD"], stderr_to_stdout: true) do
      {count, 0} -> 
        count_int = String.trim(count) |> String.to_integer()
        if count_int > 0, do: count_int, else: nil
      _ -> nil
    end
  end

  defp get_commits_behind_master do
    case System.cmd("git", ["rev-list", "--count", "HEAD..master"], stderr_to_stdout: true) do
      {count, 0} -> 
        count_int = String.trim(count) |> String.to_integer()
        if count_int > 0, do: count_int, else: nil
      _ -> nil
    end
  end

  defp get_other_branches_ahead do
    current_branch = get_current_branch()
    
    case System.cmd("git", ["branch"], stderr_to_stdout: true) do
      {branches_output, 0} ->
        branches_output
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.map(&String.replace_prefix(&1, "* ", ""))
        |> Enum.reject(&(&1 == current_branch))
        |> Enum.map(fn branch ->
          ahead = case System.cmd("git", ["rev-list", "--count", "master..#{branch}"], stderr_to_stdout: true) do
            {count, 0} ->
              count_int = String.trim(count) |> String.to_integer()
              if count_int > 0, do: count_int, else: nil
            _ -> nil
          end
          
          behind = case System.cmd("git", ["rev-list", "--count", "#{branch}..master"], stderr_to_stdout: true) do
            {count, 0} ->
              count_int = String.trim(count) |> String.to_integer()
              if count_int > 0, do: count_int, else: nil
            _ -> nil
          end
          
          if ahead || behind do
            {branch, ahead, behind}
          else
            nil
          end
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.sort_by(fn {_branch, ahead, _behind} -> -(ahead || 0) end)
      _ -> []
    end
  end

  defp build_directory_tree(path) do
    File.ls!(path)
    |> Enum.reject(&String.starts_with?(&1, "."))
    |> Enum.sort()
    |> Enum.map(fn item ->
      item_path = Path.join(path, item)
      if File.dir?(item_path) do
        children = build_directory_tree(item_path)
        %{name: item, type: :directory, children: children}
      else
        %{name: item, type: :file}
      end
    end)
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("open_file", %{"path" => path}, socket) do
    File.cwd!()
    |> Path.join(path)
    |> open_in_editor()
    
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
      <div class="min-h-screen bg-gradient-to-br from-base-200 to-base-300 py-12 px-4 sm:px-6 lg:px-8">
        <div class="max-w-7xl mx-auto">
          <div class="grid grid-cols-2 gap-6">
            <div class="space-y-6">
              <GitWidget.git_widget
                current_branch={@current_branch}
                commits_ahead={@commits_ahead}
                commits_behind={@commits_behind}
                other_branches={@other_branches}
              />

              <GuidelinesViewer.guidelines_viewer
                project_guidelines={@project_guidelines}
                fork_usage_rules={@fork_usage_rules}
                package_usage_rules={@package_usage_rules}
                agents_tree={@agents_tree}
              />
            </div>
            <div>
            </div>
          </div>

          <div class="card bg-base-100 shadow-xl mt-6">
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

  attr :item, :map, required: true

  defp open_in_editor(file_path) do
    System.cmd("open", ["-a", "VSCodium", file_path], stderr_to_stdout: true)
  end
end
