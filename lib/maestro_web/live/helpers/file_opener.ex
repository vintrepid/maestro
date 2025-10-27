defmodule MaestroWeb.Live.Helpers.FileOpener do
  @moduledoc """
  Helper module for opening files in an external editor.
  
  Usage:
  
  In your LiveView:
  
      use MaestroWeb, :live_view
      import MaestroWeb.Live.Helpers.FileOpener
  
      def handle_event("open_file", %{"path" => path}, socket) do
        open_file(path)
        {:noreply, socket}
      end
  """

  @doc """
  Opens a file in the configured editor.
  
  The path can be relative (will be resolved from project root) or absolute.
  Editor command is configured in config/config.exs as :editor_command.
  """
  def open_file(path) when is_binary(path) do
    file_path = if Path.type(path) == :absolute do
      path
    else
      Path.join(File.cwd!(), path)
    end
    
    editor_command = Application.get_env(:maestro, :editor_command, "codium")
    open_in_editor(file_path, editor_command)
  end

  defp open_in_editor(file_path, editor_command) do
    System.cmd(editor_command, [file_path], stderr_to_stdout: true)
  end
end
