defmodule MaestroWeb.ConceptsHTML do
  @moduledoc false
  use MaestroWeb, :html
  import MaestroWeb.Live.Helpers.FileOpener

  embed_templates "concepts_html/*"
end
