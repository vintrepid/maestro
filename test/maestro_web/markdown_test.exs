defmodule MaestroWeb.MarkdownTest do
  use ExUnit.Case, async: true

  test "renders Markdown while removing executable HTML" do
    rendered =
      "# Safe\n\n<script>alert('unsafe')</script>"
      |> MaestroWeb.Markdown.render()
      |> Phoenix.HTML.safe_to_string()

    assert rendered =~ "<h1>Safe</h1>"
    refute rendered =~ "<script"
    refute rendered =~ "alert('unsafe')"
  end
end
