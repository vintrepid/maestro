defmodule MaestroWeb.AdminLive.TailwindAnalysisLive do
  use MaestroWeb, :live_view
  use LiveTable.LiveResource

  import Ecto.Query
  alias Maestro.Analysis.TailwindClassUsage
  alias Maestro.Repo

  def repo, do: Maestro.Repo

  @impl true
  def mount(_params, _session, socket) do
    timestamps = TailwindClassUsage.available_timestamps()
    selected_timestamp = List.first(timestamps)
    analysis_summary = TailwindClassUsage.analysis_summary()
    projects = TailwindClassUsage.available_projects()
    selected_project = "all"

    socket =
      socket
      |> assign(:page_title, "Tailwind Class Analysis")
      |> assign(:data_provider, {__MODULE__, :list_class_usage, []})
      |> assign(:selected_class, nil)
      |> assign(:available_timestamps, timestamps)
      |> assign(:selected_timestamp, selected_timestamp)
      |> assign(:analysis_summary, analysis_summary)
      |> assign(:show_run_form, false)
      |> assign(:run_description, "")
      |> assign(:available_projects, projects)
      |> assign(:selected_project, selected_project)
      |> assign_summary_stats(selected_timestamp, selected_project)

    {:ok, socket}
  end

  defp assign_summary_stats(socket, analyzed_at, project_name) do
    project_filter = if project_name == "all", do: nil, else: project_name
    summary = TailwindClassUsage.summary_stats(analyzed_at, project_filter)
    category_stats = TailwindClassUsage.category_stats(analyzed_at, project_filter)
    file_stats = TailwindClassUsage.file_stats(analyzed_at, project_filter)

    total_unique = length(summary)
    total_occurrences = Enum.sum(Enum.map(summary, & &1.total_occurrences))

    socket
    |> assign(:summary_stats, summary)
    |> assign(:category_stats, category_stats)
    |> assign(:file_stats, file_stats)
    |> assign(:total_unique, total_unique)
    |> assign(:total_occurrences, total_occurrences)
  end

  def list_class_usage do
    from(c in TailwindClassUsage,
      select: %{
        id: c.id,
        class_name: c.class_name,
        category: c.category,
        description: c.description,
        file_path: c.file_path,
        line_number: c.line_number,
        context: c.context
      }
    )
  end

  def fields do
    [
      class_name: %{
        label: "Class",
        sortable: true,
        searchable: true,
        renderer: &render_class_name/1
      },
      category: %{
        label: "Category",
        sortable: true,
        searchable: true,
        renderer: &render_category/1
      },
      file_path: %{label: "File", sortable: true, searchable: true, renderer: &render_file/1},
      line_number: %{label: "Line", sortable: true},
      context: %{label: "Context", sortable: false, renderer: &render_context/1}
    ]
  end

  def filters do
    []
  end

  defp render_class_name(class_name) do
    assigns = %{class_name: class_name}

    ~H"""
    <code class="py-1 px-2 text-sm rounded bg-base-200">{@class_name}</code>
    """
  end

  defp render_category(category) do
    badge_class =
      case category do
        "daisyui-component" -> "badge-primary"
        "daisyui-theme" -> "badge-secondary"
        "spacing" -> "badge-info"
        "typography" -> "badge-accent"
        "sizing" -> "badge-warning"
        _ -> "badge-ghost"
      end

    assigns = %{category: category, badge_class: badge_class}

    ~H"""
    <span class={"badge badge-sm #{@badge_class}"}>{@category}</span>
    """
  end

  defp render_file(file_path) do
    short_path = String.replace_prefix(file_path, "lib/", "")
    assigns = %{file_path: short_path}

    ~H"""
    <span class="font-mono text-sm">{@file_path}</span>
    """
  end

  defp render_context(context) do
    truncated =
      context
      |> String.trim()
      |> String.slice(0..100)

    assigns = %{context: truncated}

    ~H"""
    <span class="text-xs text-base-content/70">{@context}</span>
    """
  end

  def table_options do
    %{
      pin_header: true,
      zebra: true,
      pagination: %{
        default_size: 50,
        sizes: [25, 50, 100, 250]
      }
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div>
        <div class="flex gap-6 justify-between items-start mb-6">
          <div>
            <h1>Tailwind Class Analysis</h1>
            <p class="text-base-content/70 text-sm">
              Analyze and optimize CSS class usage across projects
            </p>
          </div>

          <div class="flex gap-4 items-center">
            <%= if @available_projects != [] do %>
              <form phx-change="select_project" class="form-control">
                <label class="label py-0 pb-1">
                  <span class="label-text text-xs">Project:</span>
                </label>
                <select
                  class="select select-bordered"
                  name="project"
                >
                  <option value="all" selected={@selected_project == "all"}>
                    All Projects
                  </option>
                  <%= for project <- @available_projects do %>
                    <option
                      value={project}
                      selected={project == @selected_project}
                    >
                      {project}
                    </option>
                  <% end %>
                </select>
              </form>
            <% end %>

            <button
              class="btn btn-primary"
              phx-click="toggle_run_form"
            >
              <.icon name="hero-play" class="w-4 h-4" /> Run New Analysis
            </button>
          </div>
        </div>

        <%= if @show_run_form do %>
          <.card class="mb-6 bg-primary/5">
            <form phx-submit="run_analysis" class="flex gap-4 items-end">
              <div class="flex-1 form-control">
                <label class="label">
                  <span class="label-text font-semibold">Analysis Description (optional)</span>
                </label>
                <input
                  type="text"
                  name="description"
                  class="input input-bordered"
                  placeholder="e.g., After home page refactor"
                  value={@run_description}
                />
              </div>
              <button type="submit" class="btn btn-success">
                <.icon name="hero-play" class="w-4 h-4" /> Start Analysis
              </button>
              <button
                type="button"
                class="btn btn-ghost"
                phx-click="toggle_run_form"
              >
                Cancel
              </button>
            </form>
          </.card>
        <% end %>

        <.section_card class="mb-6">
          <h2 class="card-title">Analysis History</h2>
          <div class="overflow-x-auto">
            <.simple_table>
              <thead>
                <tr>
                  <th>Timestamp</th>
                  <th>Project</th>
                  <th>Description</th>
                  <th class="text-right">Unique Classes</th>
                  <th class="text-right">Total Uses</th>
                  <th class="text-right">Avg/Class</th>
                  <th class="text-right">Change</th>
                  <th class="text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                <%= for {run, index} <- Enum.with_index(@analysis_summary) do %>
                  <tr
                    class="hover cursor-pointer"
                    phx-click="select_run"
                    phx-value-timestamp={DateTime.to_iso8601(run.analyzed_at)}
                    phx-value-project={run.project_name}
                  >
                    <td>
                      <span class="font-mono text-xs">
                        {Calendar.strftime(run.analyzed_at, "%b %d, %I:%M %p")}
                      </span>
                    </td>
                    <td>
                      <span class="badge badge-sm badge-primary">{run.project_name}</span>
                    </td>
                    <td>
                      <%= if run.description do %>
                        <span class="badge badge-sm">{run.description}</span>
                      <% else %>
                        <span class="text-base-content/40 italic">No description</span>
                      <% end %>
                    </td>
                    <td class="text-right font-mono">{run.unique_classes}</td>
                    <td class="text-right font-mono font-semibold">{run.total_occurrences}</td>
                    <td class="text-right font-mono">
                      <%= if run.unique_classes > 0 do %>
                        {Float.round(run.total_occurrences / run.unique_classes, 1)}
                      <% else %>
                        0.0
                      <% end %>
                    </td>
                    <td class="text-right">
                      <%= if index < length(@analysis_summary) - 1 do %>
                        <% prev = Enum.at(@analysis_summary, index + 1) %>
                        <% change = run.total_occurrences - prev.total_occurrences %>
                        <span class={[
                          "badge badge-sm",
                          if(change > 0, do: "badge-warning", else: "badge-success")
                        ]}>
                          {if change > 0, do: "+#{change}", else: change}
                        </span>
                      <% else %>
                        <span class="badge badge-sm badge-ghost">Baseline</span>
                      <% end %>
                    </td>
                    <td class="text-right">
                      <button
                        phx-click="delete_run"
                        phx-value-timestamp={DateTime.to_iso8601(run.analyzed_at)}
                        class="btn btn-ghost btn-xs text-error"
                        data-confirm="Delete this analysis run?"
                      >
                        <.icon name="hero-trash" class="w-4 h-4" />
                      </button>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </.simple_table>
          </div>
        </.section_card>

        <.stats_grid class="mb-6 w-full">
          <div class="stat">
            <div class="stat-title">Total Unique Classes</div>
            <div class="stat-value text-primary">{@total_unique}</div>
            <div class="stat-desc">Across all files</div>
          </div>

          <div class="stat">
            <div class="stat-title">Total Occurrences</div>
            <div class="stat-value text-secondary">{@total_occurrences}</div>
            <div class="stat-desc">Usage instances</div>
          </div>

          <div class="stat">
            <div class="stat-title">Average per Class</div>
            <div class="stat-value">
              <%= if @total_unique > 0 do %>
                {Float.round(@total_occurrences / @total_unique, 1)}
              <% else %>
                0.0
              <% end %>
            </div>
            <div class="stat-desc">Occurrences</div>
          </div>
        </.stats_grid>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
          <.section_card class="lg:col-span-2">
            <h2 class="card-title">Top 20 Most Used Classes</h2>
            <div class="overflow-x-auto">
              <.simple_table>
                <thead>
                  <tr>
                    <th>Class</th>
                    <th>Category</th>
                    <th class="text-right">Count</th>
                    <th class="text-right">Files</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for stat <- Enum.take(@summary_stats, 20) do %>
                    <tr
                      class="cursor-pointer hover"
                      phx-click="select_class"
                      phx-value-class={stat.class_name}
                    >
                      <td><code class="text-xs">{stat.class_name}</code></td>
                      <td>
                        <span class="badge badge-xs">
                          {List.first(stat.category) || "unknown"}
                        </span>
                      </td>
                      <td class="text-right font-semibold">{stat.total_occurrences}</td>
                      <td class="text-right">{stat.file_count}</td>
                    </tr>
                  <% end %>
                </tbody>
              </.simple_table>
            </div>
          </.section_card>

          <.section_card>
            <h2 class="card-title">By Category</h2>
            <div class="space-y-2">
              <%= for stat <- @category_stats do %>
                <div class="flex justify-between items-center p-2 rounded hover:bg-base-200">
                  <span class="font-medium">{stat.category}</span>
                  <div class="text-right">
                    <div class="font-bold">{stat.total_occurrences}</div>
                    <div class="text-xs text-base-content/70">{stat.unique_classes} unique</div>
                  </div>
                </div>
              <% end %>
            </div>
          </.section_card>
        </div>

        <.section_card class="mb-6">
          <h2 class="card-title">Top Files by Class Usage</h2>
          <div class="overflow-x-auto">
            <.simple_table>
              <thead>
                <tr>
                  <th>File</th>
                  <th class="text-right">Unique Classes</th>
                  <th class="text-right">Total Uses</th>
                </tr>
              </thead>
              <tbody>
                <%= for stat <- Enum.take(@file_stats, 15) do %>
                  <tr class="hover">
                    <td>
                      <span class="font-mono text-xs">
                        {String.replace_prefix(stat.file_path, "lib/", "")}
                      </span>
                    </td>
                    <td class="text-right">{stat.unique_classes}</td>
                    <td class="text-right font-semibold">{stat.total_occurrences}</td>
                  </tr>
                <% end %>
              </tbody>
            </.simple_table>
          </div>
        </.section_card>

        <.section_card>
          <h2 class="card-title">All Class Usage</h2>
          <p class="text-sm text-base-content/70 mb-4">
            Click on a row in "Top 20" above to filter by that class, or use the search/filters below.
          </p>
          <.live_table
            id="tailwind-class-usage-table"
            fields={fields()}
            filters={filters()}
            options={@options}
            streams={@streams}
            table_options={table_options()}
          />
        </.section_card>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("select_class", %{"class" => class_name}, socket) do
    socket = assign(socket, :selected_class, class_name)
    {:noreply, push_event(socket, "filter_by_class", %{class: class_name})}
  end

  @impl true
  def handle_event("select_timestamp", %{"timestamp" => timestamp_str}, socket) do
    {:ok, timestamp, _} = DateTime.from_iso8601(timestamp_str)

    socket =
      socket
      |> assign(:selected_timestamp, timestamp)
      |> assign_summary_stats(timestamp, socket.assigns.selected_project)

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "select_run",
        %{"timestamp" => timestamp_str, "project" => project_name},
        socket
      ) do
    {:ok, timestamp, _} = DateTime.from_iso8601(timestamp_str)

    socket =
      socket
      |> assign(:selected_timestamp, timestamp)
      |> assign(:selected_project, project_name)
      |> assign_summary_stats(timestamp, project_name)

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_project", %{"project" => project_name}, socket) do
    socket =
      socket
      |> assign(:selected_project, project_name)
      |> assign_summary_stats(socket.assigns.selected_timestamp, project_name)

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_run_form", _, socket) do
    {:noreply, assign(socket, :show_run_form, !socket.assigns.show_run_form)}
  end

  @impl true
  def handle_event("delete_run", %{"timestamp" => timestamp_str}, socket) do
    {:ok, timestamp, _} = DateTime.from_iso8601(timestamp_str)

    {count, _} =
      Repo.delete_all(
        from c in TailwindClassUsage,
          where: c.analyzed_at == ^timestamp
      )

    timestamps = TailwindClassUsage.available_timestamps()
    selected_timestamp = List.first(timestamps) || socket.assigns.selected_timestamp

    socket =
      socket
      |> assign(:available_timestamps, timestamps)
      |> assign(:selected_timestamp, selected_timestamp)
      |> assign(:analysis_summary, TailwindClassUsage.analysis_summary())
      |> assign_summary_stats(selected_timestamp, socket.assigns.selected_project)
      |> put_flash(:info, "Deleted #{count} records from analysis run")

    {:noreply, socket}
  end

  @impl true
  def handle_event("run_analysis", %{"description" => description}, socket) do
    description = if description == "", do: nil, else: description

    Task.start(fn ->
      System.cmd(
        "mix",
        ["analyze_tailwind", "--load-db"] ++
          if(description, do: ["--description", description], else: [])
      )
    end)

    {:noreply,
     socket
     |> put_flash(:info, "Analysis started! Refresh page in a moment to see results.")
     |> assign(:show_run_form, false)
     |> assign(:run_description, "")}
  end
end
