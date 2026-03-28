defmodule Maestro.HEExParser do
  @moduledoc """
  Delegates to `MaestroTool.HEExParser` — the canonical HEEx parser lives in
  maestro_tool so all projects can use it.
  """

  defdelegate parse(source), to: MaestroTool.HEExParser
  defdelegate parse!(source), to: MaestroTool.HEExParser
  defdelegate traverse(nodes, fun), to: MaestroTool.HEExParser
  defdelegate to_heex(nodes), to: MaestroTool.HEExParser
  defdelegate extract_classes(nodes), to: MaestroTool.HEExParser
end
