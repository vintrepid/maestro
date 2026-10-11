defmodule Maestro.ApplicationTest do
  use ExUnit.Case, async: true

  test "production and test startup never invoke the development bootstrap" do
    assert Maestro.Application.managed_dev_children(:prod, true) == []
    assert Maestro.Application.managed_dev_children(:test, true) == []
  end

  test "development CLI startup does not launch companion servers" do
    assert Maestro.Application.managed_dev_children(:dev, false) == []
  end

  test "only a development web server owns the companion bootstrap" do
    assert [{MaestroTool.DevServer.Startup, options}] =
             Maestro.Application.managed_dev_children(:dev, true)

    assert options[:name] == Maestro.ManagedDevBootstrap
  end
end
