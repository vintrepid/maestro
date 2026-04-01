defmodule Maestro.Ops.Rule.LintConfig do
  @moduledoc """
  Embedded config for linter-type rules.

  Supports two check strategies:
  - **Regex** — `pattern` field: grep-style matching against source (with string literal stripping)
  - **AST module** — `check_module` field: fully-qualified module name implementing
    `MaestroTool.Lint.Check` behaviour (check/2, meta/0, optional fix/1)

  When `check_module` is set, the audit runner delegates to that module for detection
  and fixing. When only `pattern` is set, regex matching is used. Both can coexist.
  """

  @derive {Jason.Encoder, except: [:__meta__]}

  use Ash.Resource,
    data_layer: :embedded

  actions do
    defaults [:read, create: :*, update: :*]
  end

  attributes do
    attribute :pattern, :string do
      public? true
      description "Regex pattern for linter checks (compiled at runtime)"
    end

    attribute :check_module, :string do
      public? true
      description "Fully-qualified module implementing MaestroTool.Lint.Check (e.g. MaestroTool.Lint.Checks.BangInHandleEvent)"
    end

    attribute :file_types, {:array, :string} do
      public? true
      default []
      description "File types to check: ex, heex"
    end

    attribute :message, :string do
      public? true
      description "Message shown when the lint pattern matches"
    end

    attribute :exclude_paths, {:array, :string} do
      public? true
      default []
      description "Path substrings to exclude from this check"
    end

    attribute :only_paths, {:array, :string} do
      public? true
      default []
      description "If non-empty, only check files matching these path substrings"
    end

    attribute :fixable, :boolean do
      public? true
      default false
      description "Whether this check has an auto-fix implementation"
    end
  end
end
