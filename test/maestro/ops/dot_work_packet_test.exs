defmodule Maestro.Ops.DotWorkPacketTest do
  use Maestro.DataCase, async: false
  alias Maestro.Ops.{Project, Task}
  alias Maestro.Resources.Resource

  test "the Ash work packet never promotes historical work and requires activation" do
    project =
      Maestro.Ops.get_project_by_slug("maestro") ||
        Project.create!(%{name: "Maestro", slug: "maestro", web_port: 4004})

    attrs = %{entity_type: "project", entity_id: project.id, status: :todo, task_type: :feature}
    old = Task.create!(Map.put(attrs, :title, "Historical unfinished work"))
    selected = Task.create!(Map.put(attrs, :title, "Current reviewed work"))

    metadata = %{
      "execution_enabled" => false,
      "reviewed_at" => "2026-11-12",
      "review_source" => "Explicit current decision",
      "active_task_ids" => [selected.id],
      "project_ids" => [project.id]
    }

    profile =
      Resource.create!(%{
        title: "Maestro DOT — operating process",
        owner_type: "Project",
        owner_id: project.id,
        resource_type: :other,
        metadata: metadata
      })

    packet = Resource.dot_work_packet!()
    assert Enum.map(packet.reviewed_tasks, & &1.id) == [selected.id]
    refute old.id in Enum.map(packet.reviewed_tasks, & &1.id)
    assert packet.executable_task_ids == []

    Resource.update!(profile, %{metadata: Map.put(metadata, "execution_enabled", true)})
    assert Resource.dot_work_packet!().executable_task_ids == [selected.id]

    Task.mark_complete!(selected)
    assert Resource.dot_work_packet!().executable_task_ids == []
    assert Task.by_id!(old.id).status == :todo
  end
end
