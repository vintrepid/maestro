defmodule MaestroWeb.ConceptsHTML do
  use MaestroWeb, :html
  import MaestroWeb.Live.Helpers.FileOpener

  embed_templates "concepts_html/*"
end
