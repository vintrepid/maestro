defmodule Maestro.Ops.AppState do
  @moduledoc """
  App State GenServer.
  """
  use GenServer
  require Logger

  @spec start_link(keyword()) :: term()
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @spec get_current_project() :: term()
  def get_current_project do
    GenServer.call(__MODULE__, :get_current_project)
  end

  @spec set_current_project(any()) :: term()
  def set_current_project(project_id) do
    GenServer.call(__MODULE__, {:set_current_project, project_id})
  end

  @spec get_current_task() :: term()
  def get_current_task do
    GenServer.call(__MODULE__, :get_current_task)
  end

  @spec set_current_task(any()) :: term()
  def set_current_task(task_id) do
    GenServer.call(__MODULE__, {:set_current_task, task_id})
  end

  @impl true
  def init(_state) do
    {:ok, %{current_project_id: nil, current_task_id: nil}}
  end

  @impl true
  def handle_call(:get_current_project, _from, state) do
    project =
      if state.current_project_id do
        case Maestro.Ops.Project.by_id(state.current_project_id) do
          {:ok, project} -> project
          _ -> nil
        end
      else
        nil
      end

    {:reply, project, state}
  end

  @impl true
  def handle_call({:set_current_project, project_id}, _from, state) do
    Logger.info("Setting current project to: #{project_id}")
    {:reply, :ok, %{state | current_project_id: project_id}}
  end

  @impl true
  def handle_call(:get_current_task, _from, state) do
    task =
      if state.current_task_id do
        case Maestro.Ops.Task.by_id(state.current_task_id) do
          {:ok, task} -> task
          _ -> nil
        end
      else
        nil
      end

    {:reply, task, state}
  end

  @impl true
  def handle_call({:set_current_task, task_id}, _from, state) do
    Logger.info("Setting current task to: #{task_id}")
    {:reply, :ok, %{state | current_task_id: task_id}}
  end
end
