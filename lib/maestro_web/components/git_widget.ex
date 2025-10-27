defmodule MaestroWeb.Components.GitWidget do
  use MaestroWeb, :html

  attr :current_branch, :string, required: true
  attr :commits_ahead, :integer, default: nil
  attr :commits_behind, :integer, default: nil
  attr :other_branches, :list, default: []

  def git_widget(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-xl">
      <div class="card-body py-4">
        <div class="flex items-center gap-2 mb-2">
          <.icon name="hero-code-bracket" class="w-4 h-4 text-info" />
          <span class="text-xs font-mono text-info">
            git: {@current_branch}
            <%= if @commits_ahead do %>
              <span class="badge badge-xs badge-warning ml-1">+{@commits_ahead}</span>
            <% end %>
            <%= if @commits_behind do %>
              <span class="badge badge-xs badge-error ml-1">-{@commits_behind}</span>
            <% end %>
          </span>
        </div>
        <%= if @other_branches != [] do %>
          <div>
            <div class="text-xs text-base-content/60 mb-1">Other branches:</div>
            <div class="flex flex-wrap gap-1">
              <%= for {branch, ahead, behind} <- @other_branches do %>
                <div class="badge badge-sm badge-ghost gap-1">
                  <span class="font-mono">{branch}</span>
                  <%= if ahead do %>
                    <span class="badge badge-xs badge-warning">+{ahead}</span>
                  <% end %>
                  <%= if behind do %>
                    <span class="badge badge-xs badge-error">-{behind}</span>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
