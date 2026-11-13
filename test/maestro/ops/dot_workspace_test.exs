defmodule Maestro.Ops.DotWorkspaceTest do
  use ExUnit.Case, async: true
  alias Maestro.Ops.DotWorkspace

  defp task(id, attributes \\ %{}) do
    Map.merge(%{id: id, entity_type: "project", entity_id: "maestro", status: :todo}, attributes)
  end

  defp reviewed do
    %{
      "reviewed_at" => "2026-11-12",
      "review_source" => "current user decision",
      "execution_enabled" => true,
      "active_task_ids" => [10],
      "project_ids" => ["maestro"]
    }
  end

  test "a historical open task is ineligible even when recently updated" do
    old = task(9, %{title: "Fix dependencies", updated_at: DateTime.utc_now()})
    current = task(10)
    assert DotWorkspace.eligible_tasks(reviewed(), [old, current]) == [current]
  end

  test "prepared profiles and unreviewed profiles authorize no execution" do
    for metadata <- [
          %{},
          Map.put(reviewed(), "execution_enabled", false),
          Map.delete(reviewed(), "review_source"),
          Map.delete(reviewed(), "reviewed_at")
        ] do
      assert DotWorkspace.eligible_tasks(metadata, [task(10)]) == []
    end
  end

  test "selection does not cross project or entity scope" do
    assert DotWorkspace.eligible_tasks(reviewed(), [
             task(10, %{entity_id: "other"}),
             task(10, %{entity_type: "rule"})
           ]) == []
  end

  test "completed and blocked tasks cannot be restarted by a queue selection" do
    assert DotWorkspace.eligible_tasks(reviewed(), [
             task(10, %{status: :done}),
             task(10, %{status: :blocked})
           ]) == []

    assert DotWorkspace.eligible_tasks(reviewed(), [task(10, %{status: :in_progress})]) == [
             task(10, %{status: :in_progress})
           ]
  end

  test "the current brief distinguishes direction from implementation evidence" do
    briefs = DotWorkspace.project_briefs()
    assert Enum.map(briefs, & &1.slug) == ["maestro", "calvin", "dabhand"]
    assert Enum.find(briefs, &(&1.slug == "dabhand")).description =~ "have not been revalidated"

    assert Enum.find(briefs, &(&1.slug == "maestro")).description =~
             "Historical records require review"
  end
end
