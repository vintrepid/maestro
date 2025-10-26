defmodule Maestro.Ops do
  use Ash.Domain

  resources do
    resource Maestro.Ops.Project
  end
end
