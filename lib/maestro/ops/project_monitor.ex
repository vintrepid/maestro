defmodule Maestro.Ops.ProjectMonitor do
  use GenServer
  require Logger

  alias Maestro.Ops.Project

  @check_interval :timer.seconds(10)

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get_status(project_id) do
    GenServer.call(__MODULE__, {:get_status, project_id})
  end

  @impl true
  def init(_state) do
    schedule_check()
    {:ok, %{statuses: %{}}}
  end

  @impl true
  def handle_info(:check_projects, state) do
    projects = Project |> Ash.Query.for_read(:read) |> Ash.read!()

    new_statuses =
      Enum.reduce(projects, %{}, fn project, acc ->
        status = check_port(project.web_port)
        Map.put(acc, project.id, status)
      end)

    Enum.each(projects, fn project ->
      old_status = project.status
      new_status = Map.get(new_statuses, project.id)

      if old_status != new_status do
        project
        |> Ash.Changeset.for_update(:update, %{status: new_status})
        |> Ash.update()
      end
    end)

    schedule_check()
    {:noreply, %{state | statuses: new_statuses}}
  end

  @impl true
  def handle_call({:get_status, project_id}, _from, state) do
    status = Map.get(state.statuses, project_id, :unknown)
    {:reply, status, state}
  end

  defp check_port(port) do
    case :gen_tcp.connect(~c"localhost", port, [], 1000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        :running

      {:error, _} ->
        :stopped
    end
  end

  defp schedule_check do
    Process.send_after(self(), :check_projects, @check_interval)
  end
end
