defmodule Maestro.Ops.Rules.LintExtractor do
  @moduledoc """
  Pure function: given rule content, returns lint check config if the rule
  can be expressed as a grep pattern, or nil.
  """

  @type lint_config :: map()

  @extractors [
    {~r/deprecated.*let=\{|let=\{.*deprecated/i,
     %{lint_pattern: "let=\\{[a-z]", lint_file_types: ["heex"],
       lint_message: "Deprecated <.form let={f}> syntax. Use <.form for={@form}> instead."}},

    {~r/FORBIDDEN.*changeset.*template|changeset.*template.*FORBIDDEN|NEVER pass raw changeset|to_form.*NEVER.*changeset/i,
     %{lint_pattern: "@changeset", lint_file_types: ["heex"],
       lint_message: "Raw @changeset in template. Use to_form/2 and @form instead."}},

    {~r/never.*`?(form_for|Phoenix\.HTML\.form_for)|deprecated.*(form_for|Phoenix\.HTML\.form_for)/i,
     %{lint_pattern: "Phoenix\\.HTML\\.form_for|Phoenix\\.HTML\\.inputs_for", lint_file_types: ["ex", "heex"],
       lint_message: "Deprecated Phoenix.HTML.form_for/inputs_for. Use Phoenix.Component.form/1 and inputs_for/1."}},

    {~r/never.*`?<% Enum\.each|Enum\.each.*template|never.*Enum\.each/i,
     %{lint_pattern: "<%.*Enum\\.each", lint_file_types: ["heex"],
       lint_message: "Don't use Enum.each in templates. Use <%= for item <- @collection do %> instead."}},

    {~r/never.*~E sigil|deprecated.*~E sigil|never.*`~[EL]`/i,
     %{lint_pattern: "~E[\"\"]", lint_file_types: ["ex"],
       lint_message: "Deprecated ~E sigil. Use ~H (HEEx) instead."}},

    {~r/never.*HTML comment|HTML comment.*never|<%!--.*instead of.*<!--|NEVER use HTML comments/i,
     %{lint_pattern: "<!--", lint_file_types: ["heex"],
       lint_message: "HTML comment <!-- --> will be sent to client. Use HEEx comment <%!-- --%> instead."}},

    {~r/else.?if.*never|never.*else.?if|does not support.*else.?if|NEVER use else if/i,
     %{lint_pattern: "else\\s+if\\b", lint_file_types: ["heex", "ex"],
       lint_message: "Elixir has no else if. Use cond or case for multiple conditionals."}},

    {~r/never.*phx-update=.?(append|prepend)|deprecated.*phx-update/i,
     %{lint_pattern: "phx-update=[\"'](append|prepend)[\"']", lint_file_types: ["heex"],
       lint_message: "Deprecated phx-update=\"append\"/\"prepend\". Use streams instead."}},

    {~r/never.*`?(live_redirect|live_patch)\b|deprecated.*(live_redirect|live_patch)/i,
     %{lint_pattern: "\\blive_redirect\\b|\\blive_patch\\b", lint_file_types: ["ex", "heex"],
       lint_message: "Deprecated live_redirect/live_patch. Use push_navigate/push_patch or <.link navigate={}/patch={}>."}},

    {~r/never.*Phoenix\.View|Phoenix\.View.*deprecated|Phoenix\.View.*no longer|don't use.*Phoenix\.View/i,
     %{lint_pattern: "Phoenix\\.View", lint_file_types: ["ex"],
       lint_message: "Phoenix.View is removed in Phoenix 1.7+. It is no longer needed."}},

    {~r/don't use `?String\.to_atom|String\.to_atom.*unsafe|never.*String\.to_atom/i,
     %{lint_pattern: "String\\.to_atom\\(", lint_file_types: ["ex"],
       lint_message: "String.to_atom/1 is unsafe on user input (atom table is not GC'd). Use String.to_existing_atom/1."}},

    {~r/never.*raw Ecto|Ash actions instead.*from\(\)|never.*from\(\).*query/i,
     %{lint_pattern: "\\bfrom\\s+\\w+\\s+in\\b", lint_file_types: ["ex"],
       lint_message: "Raw Ecto query detected. Use Ash actions instead of from() queries.",
       lint_exclude_paths: ["repo.ex", "migration", "seeds.exs", "data_layer"]}},

    {~r/never.*<script.*HEEx|embedded.*<script|never.*<script.*template/i,
     %{lint_pattern: "<script", lint_file_types: ["heex"],
       lint_message: "Embedded <script> tag in HEEx. Write hooks in assets/js/ and integrate with app.js instead."}},

    {~r/never.*nested.*defmodule|defmodule.*same file|never.*nest modules/i,
     %{lint_pattern: "^\\s+defmodule\\s", lint_file_types: ["ex"],
       lint_message: "Nested defmodule detected. Never nest modules in the same file."}},

    {~r/Process\.sleep.*test|test.*Process\.sleep|avoid.*Process\.sleep/i,
     %{lint_pattern: "Process\\.sleep", lint_file_types: ["ex"],
       lint_message: "Avoid Process.sleep in tests. Use Process.monitor and assert on DOWN message instead.",
       lint_only_paths: ["test/"]}},

    {~r/phx-hook.*require.*id|phx-hook.*unique.*id/i,
     %{lint_pattern: "phx-hook=", lint_file_types: ["heex"],
       lint_message: "phx-hook requires a unique DOM id on the same element. Verify id={...} is present."}},

    {~r/LiveComponent.*avoid|avoid.*LiveComponent/i,
     %{lint_pattern: "live_component\\b|LiveComponent\\b", lint_file_types: ["ex", "heex"],
       lint_message: "LiveComponent detected. Avoid LiveComponents unless you have a strong, specific need."}},

    {~r/always use `~H`|never.*`~[LE]`|never.*EEx template/i,
     %{lint_pattern: "~[LE][\"\\[]", lint_file_types: ["ex"],
       lint_message: "Deprecated template sigil. Always use ~H (HEEx) for Phoenix templates."}},

    {~r/predicate.*should not start with `is_|is_.*should end.*\?/i,
     %{lint_pattern: "def is_\\w+[^?]\\(", lint_file_types: ["ex"],
       lint_message: "Predicate functions should not start with is_ and should end with ?. Use foo? instead of is_foo."}}
  ]

  @doc "Extract lint config from rule content, or nil if not expressible as a grep."
  @spec extract(String.t()) :: lint_config() | nil
  def extract(content) do
    Enum.find_value(@extractors, fn {matcher, config} ->
      if Regex.match?(matcher, content), do: config
    end)
  end
end
