defmodule Maestro.Swim.Swimmer do
  @moduledoc """
  A swimmer with their identifying information.

  ## Attributes

    - `last_name`, `first_name` — Name
    - `usa_swimming_id` — USA Swimming registration ID (may be nil for unregistered)
    - `dob` — Date of birth
    - `gender` — "M" or "F"
    - `team_code` — Short team code (e.g. "OARI")
    - `age` — Age at time of import

  ## Public interface

    - `create/1`, `read/0`, `by_id/1`
  """

  use Ash.Resource,
    otp_app: :maestro,
    domain: Maestro.Swim,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "swim_swimmers"
    repo Maestro.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:last_name, :first_name, :usa_swimming_id, :dob, :gender, :team_code, :age]
    end

    update :update do
      primary? true
      accept [:last_name, :first_name, :usa_swimming_id, :dob, :gender, :team_code, :age]
    end
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :last_name, :string do
      allow_nil? false
      public? true
    end

    attribute :first_name, :string do
      allow_nil? false
      public? true
    end

    attribute :usa_swimming_id, :string do
      public? true
    end

    attribute :dob, :date do
      public? true
    end

    attribute :gender, :string do
      public? true
      description "M or F"
    end

    attribute :team_code, :string do
      public? true
    end

    attribute :age, :integer do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :entries, Maestro.Swim.Entry
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :by_id, get_by: [:id], action: :read
  end
end
