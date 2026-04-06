defmodule Maestro.Ops.Task.DisplayName do
  @moduledoc """
  Calculates a display name for a task: `task_type: title`.

  Examples:
  - "Plan: Calvin Payroll — resources, actions, service logic"
  - "Discussion: Always use Cinder for data tables..."
  """
  use Ash.Resource.Calculation

  @impl true
  @spec load(term(), term(), term()) :: term()
  def load(_query, _opts, _context) do
    [:task_type, :title]
  end

  @impl true
  @spec calculate(term(), term(), term()) :: term()
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record ->
      type_label = record.task_type |> to_string() |> String.capitalize()
      "#{type_label}: #{record.title}"
    end)
  end
end
