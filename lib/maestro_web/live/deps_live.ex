defmodule MaestroWeb.DepsLive do
  @moduledoc "Developer-only, local dependency inspection backed by Maestro Tool."
  use MaestroWeb, :live_view

  use Cinder.UrlSync
  use MaestroTool.DependencyUpdate.Components, components: MaestroWeb.DependencyComponents

  alias Maestro.Ops.DependencyInventory
  @project_root Path.expand("../../..", __DIR__)

  @impl true
  def mount(_params, _session, socket) do
    if Application.get_env(:maestro, :dev_routes, false) do
      if connected?(socket), do: send(self(), :refresh)

      {:ok,
       assign(socket,
         report: nil,
         error: nil,
         running?: false,
         options_form: to_form(%{"scope" => "project", "mode" => "inspect"}, as: :update),
         project_root: @project_root
       )}
    else
      {:ok,
       socket
       |> put_flash(:error, "Dependency inspection is available locally.")
       |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply,
     start_async(socket, :inventory, fn ->
       DependencyInventory.report!(@project_root, authorize?: false)
     end)}
  end

  @impl true
  def handle_async(:inventory, {:ok, report}, socket) do
    Process.send_after(self(), :refresh, 5_000)

    {:noreply,
     assign(socket,
       report: report,
       error: nil,
       running?:
         get_in(report, [:maintenance, :execution, :busy?]) == true ||
           (get_in(report, [:run_progress, :running_count]) || 0) > 0
     )}
  end

  def handle_async(:inventory, {:exit, _reason}, socket) do
    Process.send_after(self(), :refresh, 10_000)
    {:noreply, assign(socket, error: "Inspection state is temporarily unavailable. Retrying.")}
  end

  def handle_async(:inspection, {:ok, _}, socket) do
    send(self(), :refresh)
    {:noreply, socket}
  end

  def handle_async(:inspection, {:exit, _reason}, socket) do
    {:noreply, assign(socket, error: "Inspection failed; retained results remain visible.")}
  end

  @impl true
  def handle_event("configure_update", %{"update" => params}, socket) do
    request = MaestroTool.DependencyUpdate.RunRequest.new(params)

    {:noreply,
     assign(
       socket,
       :options_form,
       to_form(MaestroTool.DependencyUpdate.RunRequest.form_params(request), as: :update)
     )}
  end

  def handle_event("start_update", %{"update" => params}, socket) do
    request = MaestroTool.DependencyUpdate.RunRequest.new(params)

    socket =
      assign(
        socket,
        :options_form,
        to_form(MaestroTool.DependencyUpdate.RunRequest.form_params(request), as: :update)
      )

    if request.dry_run? do
      {:noreply,
       start_async(socket, :inspection, fn ->
         Maestro.Ops.DependencyUpdate.ensure_inspection!(
           @project_root,
           %{options: [scope: request.scope, force?: true]},
           authorize?: false
         )
       end)}
    else
      start_plan(socket, request, false)
    end
  end

  def handle_event("retry_remaining", %{"update" => params}, socket) do
    start_plan(socket, MaestroTool.DependencyUpdate.RunRequest.new(params), true)
  end

  defp start_plan(socket, request, retry?) do
    plan_id = socket.assigns.report && socket.assigns.report.maintenance[:plan_id]

    if is_binary(plan_id) do
      case Maestro.Ops.DependencyUpdate.start_update(
             @project_root,
             plan_id,
             %{options: [scope: request.scope, dry_run?: request.dry_run?, retry?: retry?]},
             authorize?: false
           ) do
        {:ok, _} ->
          send(self(), :refresh)
          {:noreply, socket}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, to_string(reason))}
      end
    else
      {:noreply,
       put_flash(socket, :error, "Run a fresh inspection for this project and scope first.")}
    end
  end

  @impl true
  def handle_params(params, uri, socket) do
    params =
      if params == %{} do
        %{"type" => "forks", "update_stage" => "needs_update"}
      else
        params
      end

    {:noreply, Cinder.UrlSync.handle_params(params, uri, socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      current_user={assigns[:current_user]}
      flash={@flash}
    >
      <div id="dependency-admin">
        <h1 class="app-title">Maestro dependencies</h1>
        <p>Inspect dependencies, review the plan, and run maintenance.</p>
        <p :if={@error} role="alert">{@error}</p>
        <p :if={!@report}>Loading dependency state…</p>
        <.dependency_dashboard
          :if={@report}
          dashboard={@report.dashboard}
          project={@report.project}
          checked_at={@report.dashboard.checked_at}
          loading?={@running?}
          error={@error}
          cinder_theme={MaestroWeb.CinderTheme}
          current_user={@current_user}
          format_timestamp={&timestamp/1}
          execution={
            Map.merge(
              @report.maintenance[:execution] || %{},
              if(@running?,
                do: %{busy?: true, start_enabled?: false, retry_enabled?: false},
                else: %{busy?: false}
              )
            )
          }
          output={@report.dashboard.output}
          options_form={@options_form}
          dry_run?={@options_form[:mode].value != "apply"}
          url_state={@url_state}
        />
      </div>
    </Layouts.app>
    """
  end

  defp timestamp(nil), do: "not checked"
  defp timestamp(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp timestamp(value), do: to_string(value)
end
