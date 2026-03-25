defmodule Maestro.Swim do
  @moduledoc """
  Domain for swim meet management.

  Manages swimmers, meets, and entries imported from SD3 (SDIF v3) files.

  ## Resources

    - `Maestro.Swim.Meet` — A swim meet (name, date, location)
    - `Maestro.Swim.Swimmer` — A swimmer (name, DOB, gender, team, USA Swimming ID)
    - `Maestro.Swim.Entry` — An entry linking a swimmer to an event in a meet (with seed time)

  ## Tools

    - `Maestro.Swim.Sd3Parser` — Parses SD3 files into structs
    - `Mix.Tasks.Maestro.Swim.Import` — Imports an SD3 file into the database
  """

  use Ash.Domain, otp_app: :maestro

  resources do
    resource Maestro.Swim.Meet
    resource Maestro.Swim.Swimmer
    resource Maestro.Swim.Entry
  end
end
