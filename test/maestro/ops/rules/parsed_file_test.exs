defmodule Maestro.Ops.Rules.ParsedFileTest do
  use ExUnit.Case, async: true

  alias Maestro.Ops.Rules.ParsedFile

  @tag :tmp_dir
  test "parses block and self-closing HEEx tags through Maestro Tool", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "example_live.ex")

    File.write!(
      path,
      ~S'''
      defmodule ExampleLive do
        use Phoenix.LiveView

        def render(assigns) do
          ~H"""
          <section>
            <.input field={@form[:name]} />
            <span>{@value}</span>
          </section>
          """
        end
      end
      '''
    )

    parsed_file = ParsedFile.parse(path, tmp_dir)

    assert ParsedFile.heex_has_tag?(parsed_file, "section")
    assert ParsedFile.heex_has_tag?(parsed_file, ".input")
    refute ParsedFile.heex_has_tag?(parsed_file, "script")
  end
end
