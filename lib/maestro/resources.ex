defmodule Maestro.Resources do
  @moduledoc """
  Resources domain — Ash resource registry.
  """
  use Ash.Domain, extensions: [AshJsonApi.Domain]

  json_api do
    authorize? true
  end

  resources do
    resource Maestro.Resources.Resource
    resource Maestro.Resources.Tag
    resource Maestro.Resources.ResourceTag
    resource Maestro.Resources.TagHierarchy
  end
end
