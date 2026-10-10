defmodule Maestro.Ops.Rules.CuratorReportTest do
  use Maestro.DataCase, async: false
  alias Maestro.Ops.{Library, Rule, RuleSource, Skill}

  test "report mode does not synchronize catalogs, ingest documents, or rewrite outputs" do
    root = Path.join(System.tmp_dir!(), "curator-report-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf!(root) end)
    File.write!(Path.join(root, "RULES.md"), "retained reference export")
    File.write!(Path.join(root, "rules.json"), "retained JSON export")
    File.write!(Path.join(root, "AGENTS.md"), "not catalog input")
    before_state = catalog_state()

    File.cd!(root, fn ->
      assert :ok == Maestro.Ops.Rules.Curator.run(report: true, skip_deps: true)
    end)

    assert catalog_state() == before_state
    assert File.read!(Path.join(root, "RULES.md")) == "retained reference export"
    assert File.read!(Path.join(root, "rules.json")) == "retained JSON export"
  end

  defp catalog_state do
    Map.new([Library, Rule, RuleSource, Skill], fn resource ->
      {resource, Map.new(Ash.read!(resource), &{&1.id, Ash.Test.strip_metadata(&1)})}
    end)
  end
end
