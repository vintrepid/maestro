defmodule MaestroWeb.Live.Helpers.FileOpener do
  @moduledoc """
  Opens files in the user's configured editor.

  Uses the same detection as LiveDebugger: ELIXIR_EDITOR env var,
  then TERM_PROGRAM detection, then app config fallback.
  """

  alias LiveDebugger.App.Debugger.Utils.Editor

  def open_file(path) when is_binary(path) do
    file_path =
      if Path.type(path) == :absolute,
        do: path,
        else: Path.join(File.cwd!(), path)

    editor = Editor.detect_editor()

    if editor do
      cmd = Editor.get_editor_cmd(editor, file_path, 1)

      spawn(fn ->
        Editor.run_shell_cmd(cmd)
      end)
    end
  end
end
