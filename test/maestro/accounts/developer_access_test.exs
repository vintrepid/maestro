defmodule Maestro.Accounts.DeveloperAccessTest do
  use ExUnit.Case, async: false

  alias Maestro.Accounts.DeveloperAccess

  setup do
    original = Application.get_env(:maestro, :developer_emails)
    on_exit(fn -> Application.put_env(:maestro, :developer_emails, original) end)
  end

  test "matches configured developer emails without case sensitivity" do
    Application.put_env(:maestro, :developer_emails, ["vince@vintrepid.com"])

    assert DeveloperAccess.allowed?(%{email: "Vince@Vintrepid.com"})
    refute DeveloperAccess.allowed?(%{email: "someone@example.com"})
    refute DeveloperAccess.allowed?(nil)
  end

  test "allows authenticated users in an explicitly open development environment" do
    Application.put_env(:maestro, :developer_emails, :all)

    assert DeveloperAccess.allowed?(%{email: "developer@example.com"})
  end
end
