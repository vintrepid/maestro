defmodule MaestroWeb.AshJsonApiRouter do
  use AshJsonApi.Router,
    domains: [Maestro.Accounts, Maestro.Agents, Maestro.Resources, Maestro.Ops],
    open_api: "/open_api"
end
