defmodule Mix.Tasks.Maestro.Gen.SkillsTest do
  use ExUnit.Case, async: true

  test "retired generator refuses even an explicit write and leaves its target untouched" do
    root = Path.join(System.tmp_dir!(), "retired-skills-#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf!(root) end)

    assert_raise Mix.Error, ~r/skill generation is retired/, fn ->
      Mix.Tasks.Maestro.Gen.Skills.run(["--write", "--output", root])
    end

    refute File.exists?(root)
  end
end
