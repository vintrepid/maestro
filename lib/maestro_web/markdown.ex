defmodule MaestroWeb.Markdown do
  @moduledoc "Renders user-editable Markdown with a conservative HTML sanitizer."

  @spec render(String.t() | nil) :: Phoenix.HTML.safe()
  def render(nil), do: Phoenix.HTML.raw("")

  def render(markdown) when is_binary(markdown) do
    markdown
    |> MDEx.to_html!(
      render: [unsafe: true],
      sanitize: MDEx.Document.default_sanitize_options()
    )
    |> Phoenix.HTML.raw()
  end
end
