defmodule Maestro.Ops.Rule.FixConfig do
  @moduledoc """
  Embedded config for auto-fixable rules. Holds the fix strategy,
  template code, target location, and search pattern.
  """

  @derive {Jason.Encoder, except: [:__meta__]}

  use Ash.Resource,
    data_layer: :embedded

  actions do
    defaults [:read, create: :*, update: :*]
  end

  attributes do
    attribute :type, :atom do
      constraints one_of: [
                    :add_callback,
                    :add_to_mount,
                    :extract_css,
                    :replace_pattern,
                    :remove_pattern,
                    :wrap_pattern
                  ]

      description "Strategy for auto-fixing violations of this rule"
    end

    attribute :template, :string do
      description "Fix content: the code to add, the replacement, or the CSS class name"
    end

    attribute :target, :string do
      description "Where to apply: callback name, mount, template, css, or a regex match target"
    end

    attribute :search, :string do
      description "Regex pattern to find what needs fixing (for replace/remove/wrap)"
    end
  end
end
