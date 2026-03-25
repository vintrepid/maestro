defmodule Maestro.Swim do
  @moduledoc """
  Domain for swim meet management.

  Manages swimmers, meets, events, and entries imported from swim data files.

  ## Resources

    - `Maestro.Swim.Meet` — A swim meet (name, date, location)
    - `Maestro.Swim.Swimmer` — A swimmer (name, DOB, gender, team, USA Swimming ID)
    - `Maestro.Swim.Entry` — An entry linking a swimmer to an event in a meet
    - `Maestro.Swim.Event` — An event definition (distance, stroke, gender, category)
    - `Maestro.Swim.SourceFile` — Tracks imported data files

  ## Parsers

    - `Maestro.Swim.Sd3Parser` — USA Swimming SD3 (SDIF v3) fixed-width files
    - `Maestro.Swim.HyvParser` — Hy-Tek .hyv event files
    - `Maestro.Swim.Ev3Parser` — Hy-Tek .ev3 event files
  """

  use Ash.Domain, otp_app: :maestro

  resources do
    resource Maestro.Swim.Meet
    resource Maestro.Swim.Swimmer
    resource Maestro.Swim.Entry
    resource Maestro.Swim.Event
    resource Maestro.Swim.SourceFile
  end
end
