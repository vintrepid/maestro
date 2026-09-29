defmodule Mix.Tasks.Maestro.Gen.ClaudeMdTest do
  @moduledoc """
  The generated guidelines must preserve the direction stored through Rule actions.
  This exercises the full generator shell so a formatter regression cannot silently
  turn a prohibition into a requirement again.
  """

  use Maestro.DataCase, async: false

  alias Maestro.Ops.Rule

  test "an approved prohibition is generated as NEVER, not ALWAYS" do
    rule =
      Rule.create!(
        %{
          content: "**Never** log authentication tokens",
          category: :deployment,
          severity: :must
        },
        authorize?: false
      )

    Rule.approve!(rule, authorize?: false)

    output = Path.join(System.tmp_dir!(), "maestro-guidelines-#{System.unique_integer()}.md")
    on_exit(fn -> File.rm(output) end)

    Mix.Task.reenable("maestro.gen.claude_md")
    Mix.Tasks.Maestro.Gen.ClaudeMd.run(["--project", "calvin", "--output", output])

    guidelines = File.read!(output)

    assert guidelines =~ "**NEVER** log authentication tokens"
    refute guidelines =~ "**ALWAYS** log authentication tokens"
  end

  test "shared workflow rules are routed to Maestro Tool instead of copied into the app" do
    rule =
      Rule.create!(
        %{
          content: "Prior approvals do not carry forward across commits. Stop and ask again.",
          category: :deployment,
          severity: :must
        },
        authorize?: false
      )

    Rule.approve!(rule, authorize?: false)

    output =
      Path.join(System.tmp_dir!(), "maestro-workflow-routing-#{System.unique_integer()}.md")

    on_exit(fn -> File.rm(output) end)
    Mix.Task.reenable("maestro.gen.claude_md")
    Mix.Tasks.Maestro.Gen.ClaudeMd.run(["--project", "calvin", "--output", output])

    guidelines = File.read!(output)
    assert guidelines =~ MaestroTool.GuidancePolicy.workflow_reference()
    refute guidelines =~ "Prior approvals do not carry forward"
  end
end
