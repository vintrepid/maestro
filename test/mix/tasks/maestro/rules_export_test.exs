defmodule Mix.Tasks.Maestro.Rules.ExportTest do
  use Maestro.DataCase, async: false

  test "catalog export does not overwrite or generate agent entry points" do
    root = Path.join(System.tmp_dir!(), "maestro-reference-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf!(root) end)
    File.write!(Path.join(root, "AGENTS.md"), "small workflow entry point")

    Mix.Tasks.Maestro.Rules.Export.run(["--dir", root])

    assert File.read!(Path.join(root, "AGENTS.md")) == "small workflow entry point"
    refute File.exists?(Path.join(root, "CLAUDE.md"))
    assert File.read!(Path.join(root, "RULES.md")) =~ "Reference material only"
  end
end
