defmodule Maestro.ReleaseSchemaTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias Maestro.Ops.{DevServerProject, Project, Task}
  alias Maestro.Resources.Resource

  setup do
    # Exercise the ordinary release entry point on the host-only test schema.
    # Migrations need two independent connections, outside a sandbox transaction.
    Sandbox.mode(Maestro.Repo, :auto)

    try do
      assert :ok = Maestro.Release.migrate()
      assert :ok = Maestro.Release.migrate()
    after
      Sandbox.mode(Maestro.Repo, :manual)
    end

    owner = Sandbox.start_owner!(Maestro.Repo, shared: true)
    on_exit(fn -> Sandbox.stop_owner(owner) end)
    :ok
  end

  test "a released host can prepare the DOT workspace without activating historical work" do
    for {slug, port} <- [{"maestro", 9850}, {"calvin", 9852}, {"dabhand", 9854}] do
      DevServerProject.configure_startup!(%{
        name: slug,
        slug: slug,
        project_path: Path.join(System.tmp_dir!(), slug),
        app_port: port,
        start_on_login: false
      })
    end

    project = Project.create!(%{name: "Maestro", slug: "maestro", web_port: 9850})

    historical =
      Task.create!(%{
        title: "Unreviewed historical work",
        entity_type: "project",
        entity_id: project.id,
        status: :todo,
        task_type: :feature
      })

    assert Resource.refresh_dot_workspace!(%{apply: false}).mode == "preview"
    Resource.refresh_dot_workspace!(%{apply: true})
    resource_count = Ash.count!(Resource, authorize?: false)
    task_count = Ash.count!(Task, authorize?: false)
    Resource.refresh_dot_workspace!(%{apply: true})
    assert Ash.count!(Resource, authorize?: false) == resource_count
    assert Ash.count!(Task, authorize?: false) == task_count

    packet = Resource.dot_work_packet!()
    assert packet.executable_task_ids == []
    refute historical.id in Enum.map(packet.reviewed_tasks, & &1.id)
    assert Task.by_id!(historical.id).status == :todo
  end
end
