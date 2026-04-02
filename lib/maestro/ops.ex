defmodule Maestro.Ops do
  use Ash.Domain, otp_app: :maestro

  @moduledoc """
  Ops domain — Ash resource registry.
  """

  resources do
    resource Maestro.Ops.Project
    resource Maestro.Ops.Task
    resource Maestro.Ops.Rule
    resource Maestro.Ops.Library
    resource Maestro.Ops.RuleSource
    resource Maestro.Ops.Skill
    resource Maestro.Ops.Audit
    resource Maestro.Ops.AuditResult
    resource Maestro.Ops.AgentSession
    resource Maestro.Ops.AgentSessionRule
  end

  alias Maestro.Ops.Project

  @spec get_project_by_slug(any()) :: term()
  def get_project_by_slug(slug_value) do
    import Ash.Query

    case Project
         |> filter(slug == ^slug_value)
         |> limit(1)
         |> Ash.read(authorize?: false) do
      {:ok, [project | _]} -> project
      _ -> nil
    end
  end
end
