defmodule MaestroWeb.LiveViewHelpers do
  @moduledoc """
  Injected into every LiveView via @before_compile.
  Adds a catch-all handle_event for shared layout events like open_file.
  """

  defmacro __before_compile__(_env) do
    quote do
      def handle_event("open_file", %{"path" => path}, socket) do
        MaestroWeb.Live.Helpers.FileOpener.open_file(path)
        {:noreply, socket}
      end
    end
  end
end
