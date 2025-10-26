defmodule MaestroWeb.AdminLive.ComponentReplacementLive do
  use MaestroWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    examples = [
      %{
        name: "Section Card - Basic",
        html: """
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title">Analysis History</h2>
            <p>Some content here</p>
          </div>
        </div>
        """
      },
      %{
        name: "Section Card - With Extra Classes",
        html: """
        <div class="card bg-base-100 shadow-xl mb-6">
          <div class="card-body">
            <h2 class="card-title">Top Files</h2>
            <div class="overflow-x-auto">
              <table>...</table>
            </div>
          </div>
        </div>
        """
      },
      %{
        name: "Section Card - Large Span",
        html: """
        <div class="card bg-base-100 shadow-xl lg:col-span-2">
          <div class="card-body">
            <h2 class="card-title">Top 20 Most Used Classes</h2>
            <div class="overflow-x-auto">
              <table>...</table>
            </div>
          </div>
        </div>
        """
      },
      %{
        name: "Stats Grid",
        html: """
        <div class="stats stats-vertical lg:stats-horizontal shadow mb-6 w-full">
          <div class="stat">
            <div class="stat-title">Total Unique Classes</div>
            <div class="stat-value text-primary">200</div>
            <div class="stat-desc">Across all files</div>
          </div>
          <div class="stat">
            <div class="stat-title">Total Occurrences</div>
            <div class="stat-value text-secondary">519</div>
            <div class="stat-desc">Usage instances</div>
          </div>
        </div>
        """
      }
    ]

    patterns = [
      %{
        name: "section_card",
        description: "Replace card div pattern with <.section_card>",
        pattern: ~s{<div class="card bg-base-100 shadow-xl(?: ([^"]*))?">\n  <div class="card-body">},
        replacement: ~s{<.section_card class="\\1">},
        close_pattern: ~s{  </div>\n</div>},
        close_replacement: ~s{</.section_card>}
      },
      %{
        name: "stats_grid",
        description: "Replace stats div pattern with <.stats_grid>",
        pattern: ~s{<div class="stats stats-vertical lg:stats-horizontal shadow(?: ([^"]*))?"(?: [^>]*)?>},
        replacement: ~s{<.stats_grid class="\\1">},
        close_pattern: ~s{</div>},
        close_replacement: ~s{</.stats_grid>}
      }
    ]

    {:ok,
     socket
     |> assign(:current_user, socket.assigns[:current_user])
     |> assign(:examples, examples)
     |> assign(:patterns, patterns)
     |> assign(:selected_example, 0)
     |> assign(:selected_pattern, 0)
     |> assign(:custom_html, "")
     |> assign(:custom_pattern, "")
     |> assign(:custom_replacement, "")
     |> assign(:use_custom, false)
     |> apply_transformation()}
  end

  @impl true
  def handle_event("select_example", %{"index" => index}, socket) do
    {:noreply,
     socket
     |> assign(:selected_example, String.to_integer(index))
     |> assign(:use_custom, false)
     |> apply_transformation()}
  end

  @impl true
  def handle_event("select_pattern", %{"index" => index}, socket) do
    {:noreply,
     socket
     |> assign(:selected_pattern, String.to_integer(index))
     |> assign(:use_custom, false)
     |> apply_transformation()}
  end

  @impl true
  def handle_event("update_custom_html", %{"html" => html}, socket) do
    {:noreply,
     socket
     |> assign(:custom_html, html)
     |> assign(:use_custom, true)
     |> apply_transformation()}
  end

  @impl true
  def handle_event("update_custom_pattern", %{"pattern" => pattern}, socket) do
    {:noreply,
     socket
     |> assign(:custom_pattern, pattern)
     |> assign(:use_custom, true)
     |> apply_transformation()}
  end

  @impl true
  def handle_event("update_custom_replacement", %{"replacement" => replacement}, socket) do
    {:noreply,
     socket
     |> assign(:custom_replacement, replacement)
     |> assign(:use_custom, true)
     |> apply_transformation()}
  end

  defp apply_transformation(socket) do
    html =
      if socket.assigns.use_custom && socket.assigns.custom_html != "" do
        socket.assigns.custom_html
      else
        example = Enum.at(socket.assigns.examples, socket.assigns.selected_example)
        if example, do: example.html, else: ""
      end

    pattern_data =
      if socket.assigns.use_custom && socket.assigns.custom_pattern != "" do
        %{
          pattern: socket.assigns.custom_pattern,
          replacement: socket.assigns.custom_replacement,
          close_pattern: "",
          close_replacement: ""
        }
      else
        Enum.at(socket.assigns.patterns, socket.assigns.selected_pattern) || %{}
      end

    {transformed, error} = transform_html(html, pattern_data)

    socket
    |> assign(:original_html, html)
    |> assign(:transformed_html, transformed)
    |> assign(:error, error)
    |> assign(:current_pattern, pattern_data)
  end

  defp transform_html(html, %{pattern: pattern, replacement: replacement} = pattern_data)
       when is_binary(pattern) and is_binary(replacement) do
    try do
      regex = Regex.compile!(pattern)
      
      step1 = Regex.replace(regex, html, replacement)

      step2 =
        if Map.get(pattern_data, :close_pattern) && Map.get(pattern_data, :close_pattern) != "" do
          close_regex = Regex.compile!(pattern_data.close_pattern)
          Regex.replace(close_regex, step1, pattern_data.close_replacement)
        else
          step1
        end

      {step2, nil}
    rescue
      e -> {"", Exception.message(e)}
    end
  end

  defp transform_html(_html, _), do: {"", nil}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div>
        <h1>Component Replacement Tool</h1>
        <p class="text-base-content/70 text-sm mb-6">
          Test and refine regex patterns for replacing HTML with Phoenix components
        </p>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
          <.section_card>
            <h2 class="card-title mb-4">HTML Examples</h2>
            <div class="space-y-2">
              <%= for {example, index} <- Enum.with_index(@examples) do %>
                <button
                  class={[
                    "btn btn-sm w-full justify-start",
                    if(@selected_example == index && !@use_custom, do: "btn-primary", else: "btn-ghost")
                  ]}
                  phx-click="select_example"
                  phx-value-index={index}
                >
                  {example.name}
                </button>
              <% end %>
            </div>

            <div class="divider">OR</div>

            <div class="form-control">
              <label class="label">
                <span class="label-text font-semibold">Custom HTML</span>
              </label>
              <textarea
                class="textarea textarea-bordered font-mono text-xs h-32"
                phx-blur="update_custom_html"
                name="html"
              >{@custom_html}</textarea>
            </div>
          </.section_card>

          <.section_card>
            <h2 class="card-title mb-4">Patterns</h2>
            <div class="space-y-2">
              <%= for {pattern, index} <- Enum.with_index(@patterns) do %>
                <button
                  class={[
                    "btn btn-sm w-full justify-start",
                    if(@selected_pattern == index && !@use_custom, do: "btn-primary", else: "btn-ghost")
                  ]}
                  phx-click="select_pattern"
                  phx-value-index={index}
                >
                  {pattern.name}
                </button>
              <% end %>
            </div>

            <div class="divider">OR</div>

            <div class="form-control">
              <label class="label">
                <span class="label-text font-semibold">Custom Pattern</span>
              </label>
              <textarea
                class="textarea textarea-bordered font-mono text-xs h-20"
                phx-blur="update_custom_pattern"
                name="pattern"
              >{@custom_pattern}</textarea>
            </div>

            <div class="form-control mt-2">
              <label class="label">
                <span class="label-text font-semibold">Replacement</span>
              </label>
              <textarea
                class="textarea textarea-bordered font-mono text-xs h-20"
                phx-blur="update_custom_replacement"
                name="replacement"
              >{@custom_replacement}</textarea>
            </div>
          </.section_card>

          <.section_card>
            <h2 class="card-title mb-4">Current Pattern</h2>
            <%= if @current_pattern != %{} do %>
              <div class="space-y-3">
                <div>
                  <div class="text-xs font-semibold text-base-content/70 mb-1">Open Pattern:</div>
                  <code class="block text-xs bg-base-200 p-2 rounded break-all">
                    {@current_pattern.pattern}
                  </code>
                </div>
                <div>
                  <div class="text-xs font-semibold text-base-content/70 mb-1">Replacement:</div>
                  <code class="block text-xs bg-base-200 p-2 rounded break-all">
                    {@current_pattern.replacement}
                  </code>
                </div>
                <%= if Map.get(@current_pattern, :close_pattern) && @current_pattern.close_pattern != "" do %>
                  <div>
                    <div class="text-xs font-semibold text-base-content/70 mb-1">Close Pattern:</div>
                    <code class="block text-xs bg-base-200 p-2 rounded break-all">
                      {@current_pattern.close_pattern}
                    </code>
                  </div>
                  <div>
                    <div class="text-xs font-semibold text-base-content/70 mb-1">Close Replacement:</div>
                    <code class="block text-xs bg-base-200 p-2 rounded break-all">
                      {@current_pattern.close_replacement}
                    </code>
                  </div>
                <% end %>
              </div>
            <% else %>
              <p class="text-sm text-base-content/70">Select a pattern to see details</p>
            <% end %>
          </.section_card>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <.section_card>
            <h2 class="card-title mb-4">Original HTML</h2>
            <pre class="bg-base-200 p-4 rounded text-xs overflow-x-auto"><code>{@original_html}</code></pre>
          </.section_card>

          <.section_card>
            <h2 class="card-title mb-4">Transformed HTML</h2>
            <%= if @error do %>
              <div class="alert alert-error mb-4">
                <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
                <span class="text-sm">{@error}</span>
              </div>
              <pre class="bg-base-200 p-4 rounded text-xs overflow-x-auto"><code>{@original_html}</code></pre>
            <% else %>
              <pre class="bg-base-200 p-4 rounded text-xs overflow-x-auto"><code>{@transformed_html}</code></pre>

              <div class="divider">Preview</div>

              <div class="border-2 border-dashed border-base-300 p-4 rounded">
                <div phx-no-format>
                  <%= raw(@transformed_html) %>
                </div>
              </div>
            <% end %>
          </.section_card>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
