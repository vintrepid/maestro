defmodule Maestro.Ops.AuditResult do
  @moduledoc """
  A per-page result from an audit run.

  Stores the page path, module, pass/fail/skip counts, score,
  and a JSON array of findings (each with rule_id, category, pass?, evidence).
  """

  use Ash.Resource,
    domain: Maestro.Ops,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  json_api do
    type "audit_results"

    routes do
      base "/audit-results"
      index :read
      get :read
      delete :destroy
    end
  end

  postgres do
    table "audit_results"
    repo Maestro.Repo

    references do
      reference :audit, on_delete: :delete
    end
  end

  code_interface do
    define :create
    define :read
    define :destroy
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :path,
        :module_name,
        :source_file,
        :score,
        :pass,
        :fail,
        :skip,
        :total,
        :findings,
        :audit_id
      ]
    end
  end

  attributes do
    integer_primary_key :id

    attribute :path, :string do
      allow_nil? false
    end

    attribute :module_name, :string do
      allow_nil? false
    end

    attribute :source_file, :string

    attribute :score, :integer, default: 100
    attribute :pass, :integer, default: 0
    attribute :fail, :integer, default: 0
    attribute :skip, :integer, default: 0
    attribute :total, :integer, default: 0

    attribute :findings, {:array, :map}, default: []

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :audit, Maestro.Ops.Audit do
      allow_nil? false
      attribute_type :integer
    end
  end
end
