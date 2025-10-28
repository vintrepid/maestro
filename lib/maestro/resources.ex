defmodule Maestro.Resources do
  use Ash.Domain

  resources do
    resource Maestro.Resources.Resource
    resource Maestro.Resources.Tag
    resource Maestro.Resources.ResourceTag
    resource Maestro.Resources.TagHierarchy
  end
end
