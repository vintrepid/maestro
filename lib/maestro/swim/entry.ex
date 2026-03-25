defmodule Maestro.Swim.Entry do
  @moduledoc """
  An entry linking a swimmer to an event in a meet.

  ## Attributes

    - `event_number` — Event number in the meet
    - `event_name` — Human-readable event name (e.g. "100 Free")
    - `seed_time` — Seed time as string (e.g. "56.18" or "NTY" for no time)
    - `seed_time_seconds` — Seed time in seconds for sorting (nil if NTY)
    - `course` — "Y", "L", or "S"
    - `stroke` — Stroke code (e.g. "Free", "Back", "Breast", "Fly", "IM")
    - `distance` — Distance in yards/meters

  ## Public interface

    - `create/1`, `read/0`
  """

  use Ash.Resource,
    otp_app: :maestro,
    domain: Maestro.Swim,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "swim_entries"
    repo Maestro.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [
        :meet_id, :swimmer_id, :event_number, :event_name,
        :seed_time, :seed_time_seconds, :course, :stroke, :distance
      ]
    end
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :event_number, :integer do
      allow_nil? false
      public? true
    end

    attribute :event_name, :string do
      public? true
    end

    attribute :seed_time, :string do
      public? true
      description "Display time (e.g. '56.18' or 'NT')"
    end

    attribute :seed_time_seconds, :float do
      public? true
      description "Time in seconds for sorting, nil if no time"
    end

    attribute :course, :string do
      default "Y"
      public? true
    end

    attribute :stroke, :string do
      public? true
    end

    attribute :distance, :integer do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :meet, Maestro.Swim.Meet do
      allow_nil? false
      public? true
    end

    belongs_to :swimmer, Maestro.Swim.Swimmer do
      allow_nil? false
      public? true
    end
  end

  code_interface do
    define :create
    define :read
    define :destroy
  end
end
