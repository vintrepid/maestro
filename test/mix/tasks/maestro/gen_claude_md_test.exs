defmodule Mix.Tasks.Maestro.Gen.ClaudeMdTest do
  use ExUnit.Case, async: true

  test "retired corpus generator refuses to overwrite instructions" do
    output =
      Path.join(System.tmp_dir!(), "maestro-guidance-#{System.unique_integer([:positive])}.md")

    File.write!(output, "existing instructions")
    on_exit(fn -> File.rm!(output) end)

    assert_raise Mix.Error, ~r/generation is retired/, fn ->
      Mix.Tasks.Maestro.Gen.ClaudeMd.run(["--output", output])
    end

    assert File.read!(output) == "existing instructions"
  end
end
