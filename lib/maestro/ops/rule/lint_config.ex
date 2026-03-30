defmodule Maestro.Ops.Rule.LintConfig do
  @moduledoc """
  Embedded config for linter-type rules. Holds the regex pattern,
  file types, message, and path filters for automated lint checks.
  """

  use Ash.Resource,
    data_layer: :embedded

  actions do
    defaults [:read, create: :*, update: :*]
  end

  attributes do
    attribute :pattern, :string do
      description "Regex pattern for linter checks (compiled at runtime)"
    end

    attribute :file_types, {:array, :string} do
      default []
      description "File types to check: ex, heex"
    end

    attribute :message, :string do
      description "Message shown when the lint pattern matches"
    end

    attribute :exclude_paths, {:array, :string} do
      default []
      description "Path substrings to exclude from this check"
    end

    attribute :only_paths, {:array, :string} do
      default []
      description "If non-empty, only check files matching these path substrings"
    end
  end
end
