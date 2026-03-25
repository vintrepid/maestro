defmodule Maestro.Swim.Event do
  @moduledoc """
  A meet event definition — one race in the meet lineup.

  Imported from .ev3 or .hyv files. Events define what races
  happen at a meet. Entries link swimmers to events.

  ## Attributes

    - `number` — Event number in the meet (1-48 etc.)
    - `distance` — Distance in yards/meters (50, 100, 200, 500)
    - `stroke` — "Free", "Back", "Breast", "Fly", "IM"
    - `gender` — "F" or "M"
    - `event_type` — "I" (individual) or "R" (relay)
    - `category` — "JV", "VR" (Varsity), etc.

  ## Public interface

    - `create/1`, `read/0`
  """

  use Ash.Resource,
    otp_app: :maestro,
    domain: Maestro.Swim,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "swim_events"
    repo Maestro.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:meet_id, :number, :distance, :stroke, :gender, :event_type, :category, :category_name]
    end
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :number, :integer do
      allow_nil? false
      public? true
    end

    attribute :distance, :integer do
      allow_nil? false
      public? true
    end

    attribute :stroke, :string do
      allow_nil? false
      public? true
    end

    attribute :gender, :string do
      public? true
      description "F or M"
    end

    attribute :event_type, :string do
      public? true
      description "I=individual, R=relay"
    end

    attribute :category, :string do
      public? true
      description "JV, VR, etc."
    end

    attribute :category_name, :string do
      public? true
      description "Junior Varsity, Varsity, etc."
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :meet, Maestro.Swim.Meet do
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
