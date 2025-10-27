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
  """
  def open_file(path) when is_binary(path) do
    file_path = if Path.type(path) == :absolute do
      path
    else
      Path.join(File.cwd!(), path)
    end
    
    open_in_editor(file_path)
  end

  defp open_in_editor(file_path) do
    # Use VSCodium as the default editor
    # The open command on macOS requires the app name without flags
    System.cmd("open", ["-a", "VSCodium", file_path], stderr_to_stdout: true)
  end
end
