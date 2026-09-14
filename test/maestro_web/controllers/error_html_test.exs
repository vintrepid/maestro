defmodule MaestroWeb.ErrorHTMLTest do
  use MaestroWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template, only: [render_to_string: 4]

  test "renders 404.html" do
    error_page =
      MaestroWeb.ErrorHTML
      |> render_to_string("404", "html", [])
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("#error-404")
      |> LazyHTML.to_tree()

    assert [{"div", _attributes, _children}] = error_page
  end

  test "renders 500.html" do
    error_page =
      MaestroWeb.ErrorHTML
      |> render_to_string("500", "html", [])
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("#error-500")
      |> LazyHTML.to_tree()

    assert [{"div", _attributes, _children}] = error_page
  end
end
