defmodule Mix.Tasks.Maestro.Dot.Bootstrap do
  @shortdoc "Preview or refresh the reviewed Maestro DOT workspace"
  @moduledoc """
  Previews the current DOT brief; pass --apply to refresh Maestro's existing
  project/task/resource records. Old tasks remain unchanged. This prepares data;
  it does not create a ChatGPT DOT, enable execution or grant computer access.

      mix maestro.dot.bootstrap
      mix maestro.dot.bootstrap --apply
      mix maestro.dot.bootstrap --status
  """
  use Mix.Task

  @impl true
  def run(args) do
    {opts, rest, invalid} = OptionParser.parse(args, strict: [apply: :boolean, status: :boolean])

    if rest != [] or invalid != [] or (opts[:apply] && opts[:status]),
      do: Mix.raise("Usage: mix maestro.dot.bootstrap [--apply | --status]")

    Application.put_env(:maestro, MaestroWeb.Endpoint, server: false)
    Mix.Task.run("app.start")

    result =
      if opts[:status],
        do: Maestro.Resources.Resource.dot_work_packet!(),
        else: Maestro.Resources.Resource.refresh_dot_workspace!(%{apply: opts[:apply] || false})

    Mix.shell().info(Jason.encode!(result, pretty: true))
  end
end
