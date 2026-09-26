defmodule MaestroWeb.Live.Helpers.FileOpener do
  @moduledoc """
  Opens files in the user's configured editor.

  Uses Maestro Tool's runtime editor helper so this module does not depend on
  LiveDebugger being compiled outside the development environment.
  """

  alias MaestroTool.Editor

  @spec open_file(term()) :: term()
  def open_file(path) when is_binary(path) do
    file_path =
      if Path.type(path) == :absolute,
        do: path,
        else: Path.join(File.cwd!(), path)

    editor =
      Editor.detect_editor(System.get_env(), Application.get_env(:maestro, :editor_command))

    if editor do
      command = Editor.command(editor, file_path, 1)

      spawn(fn ->
        Editor.run(command)
      end)
    end
  end
end
