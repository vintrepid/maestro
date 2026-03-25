defmodule Maestro.Swim.SourceFile do
  @moduledoc """
  Tracks imported swim data files.

  Records which files have been imported, their format, and
  what meet they belong to. Prevents duplicate imports.

  ## Attributes

    - `filename` — Original filename
    - `path` — Full path at import time
    - `format` — "sd3", "ev3", "hyv"
    - `record_count` — Number of records imported

  ## Public interface

    - `create/1`, `read/0`, `by_path/1`
  """

  use Ash.Resource,
    otp_app: :maestro,
    domain: Maestro.Swim,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "swim_source_files"
    repo Maestro.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:meet_id, :filename, :path, :format, :record_count]
    end

    read :by_path do
      argument :path, :string, allow_nil?: false
      filter expr(path == ^arg(:path))
    end
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :filename, :string do
      allow_nil? false
      public? true
    end

    attribute :path, :string do
      public? true
    end

    attribute :format, :string do
      allow_nil? false
      public? true
      description "sd3, ev3, hyv"
    end

    attribute :record_count, :integer do
      default 0
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :meet, Maestro.Swim.Meet do
      allow_nil? true
      public? true
    end
  end

  code_interface do
    define :create
    define :read
    define :destroy
    define :by_path, args: [:path]
  end
end
