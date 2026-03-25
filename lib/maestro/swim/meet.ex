defmodule Maestro.Swim.Meet do
  @moduledoc """
  A swim meet — the event that contains entries.

  ## Attributes

    - `name` — Meet name (e.g. "Folsom VS Oak Ridge")
    - `location` — Venue name
    - `meet_date` — Date of the meet
    - `course` — "Y" (yards), "L" (long course meters), "S" (short course meters)

  ## Public interface

    - `create/1`, `read/0`, `by_id/1`
  """

  use Ash.Resource,
    otp_app: :maestro,
    domain: Maestro.Swim,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "swim_meets"
    repo Maestro.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :location, :meet_date, :course, :host_team]
    end

    update :update do
      primary? true
      accept [:name, :location, :meet_date, :course, :host_team]
    end
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :location, :string do
      public? true
    end

    attribute :host_team, :string do
      public? true
    end

    attribute :meet_date, :date do
      public? true
    end

    attribute :course, :string do
      default "Y"
      public? true
      description "Y=yards, L=LCM, S=SCM"
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
