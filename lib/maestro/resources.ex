defmodule Maestro.Resources do
  @moduledoc """
  Resources domain — Ash resource registry.
  """
  use Ash.Domain

  resources do
    resource Maestro.Resources.Resource
    resource Maestro.Resources.Tag
    resource Maestro.Resources.ResourceTag
    resource Maestro.Resources.TagHierarchy
  end
end
