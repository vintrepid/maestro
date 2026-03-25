defmodule Maestro.Swim.Ev3Parser do
  @moduledoc """
  Parses Hy-Tek .ev3 event definition files.

  EV3 format: semicolon-delimited with `*>` line terminators.
  Line 1 = meet header, lines 2+ = events. Similar to .hyv but
  with additional fields (heat/lane info, time of day).

  ## Event fields (lines 2+)
    event_id;number;finals;session;type;gender;min_age;max_age;distance;stroke_code;...;category;category_name;...

  ## Stroke codes
    A=Free, B=Back, C=Breast, D=Fly, E=IM, F=Exhibition

  ## Public interface

    - `parse_file/1` — Returns `{:ok, %{meet: ..., events: [...]}}`
    - `import_file!/1` — Parses and inserts into database
  """

  alias Maestro.Swim.{Meet, Event, SourceFile}

  @stroke_codes %{
    "A" => "Free",
    "B" => "Back",
    "C" => "Breast",
    "D" => "Fly",
    "E" => "IM",
    "F" => "Exhibition"
  }

  def parse_file(path) do
    lines = File.read!(path) |> String.replace("*>", "") |> String.split(~r/\r?\n/, trim: true)
    [header | event_lines] = lines

    meet = parse_header(header)
    events = Enum.map(event_lines, &parse_event/1) |> Enum.reject(&is_nil/1)

    {:ok, %{meet: meet, events: events}}
  end

  def import_file!(path) do
    {:ok, data} = parse_file(path)

    meet = find_or_create_meet(data.meet)

    events =
      Enum.map(data.events, fn evt ->
        {:ok, event} = Event.create(Map.put(evt, :meet_id, meet.id))
        event
      end)

    {:ok, _} = SourceFile.create(%{
      meet_id: meet.id,
      filename: Path.basename(path),
      path: path,
      format: "ev3",
      record_count: length(events)
    })

    {:ok, %{meet: meet, events: events}}
  end

  defp parse_header(line) do
    parts = String.split(line, ";")
    %{
      name: Enum.at(parts, 0),
      location: Enum.at(parts, 1),
      start_date: parse_date(Enum.at(parts, 2))
    }
  end

  defp parse_event(line) do
    parts = String.split(line, ";")

    case length(parts) do
      n when n >= 12 ->
        gender = case Enum.at(parts, 5) do
          "G" -> "F"
          "B" -> "M"
          other -> other
        end

        %{
          number: parse_int(Enum.at(parts, 1)),
          gender: gender,
          event_type: Enum.at(parts, 4),
          distance: parse_int(Enum.at(parts, 8)),
          stroke: Map.get(@stroke_codes, Enum.at(parts, 9), "Unknown"),
          category: Enum.at(parts, 11, ""),
          category_name: Enum.at(parts, 12, "")
        }

      _ -> nil
    end
  end

  defp find_or_create_meet(%{name: name} = data) do
    import Ecto.Query
    case Maestro.Repo.one(from m in "swim_meets", where: m.name == ^name, select: %{id: type(m.id, :string)}, limit: 1) do
      %{id: id} -> Meet.by_id!(id)
      nil ->
        {:ok, meet} = Meet.create(%{name: name, location: data.location, meet_date: data.start_date})
        meet
    end
  end

  defp parse_date(nil), do: nil
  defp parse_date(str) do
    case String.split(str, "/") do
      [m, d, y] -> Date.new!(String.to_integer(y), String.to_integer(m), String.to_integer(d))
      _ -> nil
    end
  end

  defp parse_int(nil), do: nil
  defp parse_int(str) do
    case Integer.parse(String.trim(str)) do
      {n, _} -> n
      :error -> nil
    end
  end
end
