defmodule Maestro.Accounts.DeveloperAccess do
  @moduledoc "Production access policy for Maestro developers."

  @spec allowed?(term()) :: boolean()
  def allowed?(%{email: email}), do: allowed_email?(email)
  def allowed?(_user), do: false

  @spec allowed_email?(term()) :: boolean()
  def allowed_email?(email) do
    normalized_email = email |> to_string() |> String.trim() |> String.downcase()

    case Application.get_env(:maestro, :developer_emails, []) do
      :all -> normalized_email != ""
      emails when is_list(emails) -> normalized_email in emails
      _other -> false
    end
  end
end
