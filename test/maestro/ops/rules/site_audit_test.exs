defmodule Maestro.Ops.Rules.SiteAuditTest do
  use ExUnit.Case, async: true

  alias Maestro.Ops.Rules.SiteAudit

  test "a stored prohibition drives an absence check without marker words in its prose" do
    page = %{
      path: "lib/example.ex",
      module: Example,
      source_file: "lib/example.ex",
      source: "defmodule Example do\n  def run, do: Repo.query(:unsafe)\nend",
      ast:
        Code.string_to_quoted!("defmodule Example do\n  def run, do: Repo.query(:unsafe)\nend"),
      heex_blocks: []
    }

    rule = %{
      id: "rule-1",
      content: "Use `Repo.query` only through an approved Ash data boundary",
      category: :ash,
      directive: :forbid,
      source_project_slug: "maestro",
      lint_config: nil,
      lint_pattern: nil,
      fix_type: nil,
      fix_target: nil
    }

    [result] = SiteAudit.audit_pages([page], [rule])
    [finding] = result.findings

    refute finding.pass?
    assert finding.evidence == ["Found prohibited pattern: Repo.query"]
  end
end
