defmodule Maestro.SwooshIdnaCompatibilityTest do
  use ExUnit.Case, async: true

  test "the mailer renders internationalized recipient domains with current IDNA" do
    assert Swoosh.Email.Render.render_recipient({"Travel", "guide@bücher.example"}) ==
             ~s("Travel" <guide@xn--bcher-kva.example>)

    assert Swoosh.Email.Render.render_recipient({nil, "ops@example.com"}) == "ops@example.com"
  end
end
