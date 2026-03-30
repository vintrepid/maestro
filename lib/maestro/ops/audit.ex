defmodule Maestro.Ops.Audit do
  @moduledoc """
  Represents a single audit run against the site's pages.

  An audit discovers all LiveView pages, checks them against approved/proposed rules,
  and stores per-page results with findings. The Audit record holds the summary;
  AuditResult records hold per-page detail.
  """

  use Ash.Resource,
    domain: Maestro.Ops,
    data_layer: AshPostgres.DataLayer,
    simple_notifiers: [Maestro.Ops.AuditPubSub]

  postgres do
    table "audits"
    repo Maestro.Repo
  end

  code_interface do
    define :create
    define :read
    define :complete
    define :fail
    define :destroy
    define :by_id, get_by: [:id], action: :read
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:status, :total_modules]
    end

    update :complete do
      accept []
      change set_attribute(:status, :completed)
    end

    update :fail do
      accept []
      change set_attribute(:status, :failed)
    end
  end

  attributes do
    integer_primary_key :id

    attribute :status, :atom do
      constraints one_of: [:running, :completed, :failed]
      default :running
      allow_nil? false
    end

    attribute :total_modules, :integer, default: 0

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :results, Maestro.Ops.AuditResult
  end

  calculations do
    calculate :total_pass_modules,
              :integer,
              expr(if(total_modules > total_results, total_modules - total_results, 0))
  end

  aggregates do
    count :total_results, :results
    sum :total_fail, :results, :fail
    sum :total_pass_checks, :results, :pass
    avg :avg_score, :results, :score
  end

end
