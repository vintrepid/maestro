defmodule Maestro.Swim.Sd3Parser do
  @moduledoc """
  Parses USA Swimming SD3 (SDIF v3) fixed-width files into structured data.

  SD3 record types:
  - A01 — File description
  - B11 — Meet info
  - C11 — Team info
  - D01 — Individual entry
  - D3  — Swimmer name detail
  - E01 — Relay entry
  - Z01 — File trailer

  ## Public interface

    - `parse_file/1` — Parses an SD3 file, returns `{:ok, %{meet: ..., team: ..., entries: [...]}}`
    - `import_file!/1` — Parses and inserts into the database
  """

  alias Maestro.Swim.{Meet, Swimmer, Entry}

  @event_names %{
    {50, "Free"} => "50 Free",
    {100, "Free"} => "100 Free",
    {200, "Free"} => "200 Free",
    {500, "Free"} => "500 Free",
    {100, "Back"} => "100 Back",
    {100, "Breast"} => "100 Breast",
    {100, "Fly"} => "100 Fly",
    {100, "IM"} => "100 IM",
    {200, "IM"} => "200 IM"
  }

  # --- Public API ---

  @doc "Parses an SD3 file into a map of meet, team, and entries."
  def parse_file(path) do
    lines = File.read!(path) |> String.split(~r/\r?\n/, trim: true)

    meet = lines |> Enum.find(&String.starts_with?(&1, "B11")) |> parse_meet()
    team = lines |> Enum.find(&String.starts_with?(&1, "C11")) |> parse_team()

    entries =
      lines
      |> Enum.filter(&String.starts_with?(&1, "D01"))
      |> Enum.map(&parse_entry/1)

    {:ok, %{meet: meet, team: team, entries: entries}}
  end

  @doc "Parses an SD3 file and inserts all data into the database."
  def import_file!(path) do
    {:ok, data} = parse_file(path)

    {:ok, meet} = Meet.create(%{
      name: data.meet.name,
      location: data.meet.location,
      meet_date: data.meet.date,
      host_team: data.team.code
    })

    swimmers_cache = %{}

    {_cache, entries} =
      Enum.reduce(data.entries, {swimmers_cache, []}, fn entry_data, {cache, acc} ->
        key = {entry_data.last_name, entry_data.first_name, entry_data.dob}

        {swimmer, cache} =
          case Map.get(cache, key) do
            nil ->
              {:ok, swimmer} = Swimmer.create(%{
                last_name: entry_data.last_name,
                first_name: entry_data.first_name,
                usa_swimming_id: entry_data.usa_swimming_id,
                dob: entry_data.dob,
                gender: entry_data.gender,
                team_code: data.team.code,
                age: entry_data.age
              })
              {swimmer, Map.put(cache, key, swimmer)}

            swimmer ->
              {swimmer, cache}
          end

        {:ok, entry} = Entry.create(%{
          meet_id: meet.id,
          swimmer_id: swimmer.id,
          event_number: entry_data.event_number,
          event_name: entry_data.event_name,
          seed_time: entry_data.seed_time,
          seed_time_seconds: entry_data.seed_time_seconds,
          course: entry_data.course,
          stroke: entry_data.stroke,
          distance: entry_data.distance
        })

        {cache, [entry | acc]}
      end)

    {:ok, %{meet: meet, entries: Enum.reverse(entries)}}
  end

  # --- Parsers ---

  defp parse_meet(nil), do: %{name: nil, location: nil, date: nil}
  defp parse_meet(line) do
    %{
      name: slice(line, 11, 30),
      location: slice(line, 41, 30),
      date: parse_date(slice(line, 101, 8))
    }
  end

  defp parse_team(nil), do: %{code: nil, name: nil}
  defp parse_team(line) do
    # C11 layout: pos 11-14 = team code (4 chars), pos 15-44 = team name
    %{
      code: slice(line, 11, 4),
      name: slice(line, 15, 30)
    }
  end

  defp parse_entry(line) do
    last_first = slice(line, 11, 28)
    {last_name, first_name} = split_name(last_first)
    usa_id = slice(line, 39, 12)
    dob = parse_date(slice(line, 55, 8))
    age = parse_int(slice(line, 63, 2))
    gender = String.slice(line, 65, 1)
    event_code = slice(line, 68, 4)
    event_number = parse_int(slice(line, 74, 2))
    time_area = slice(line, 80, 17)
    {seed_time_raw, course} = extract_time_and_course(time_area)

    {distance, stroke} = decode_event(event_code)
    event_name = Map.get(@event_names, {distance, stroke}, "#{distance} #{stroke}")
    {seed_time, seed_time_seconds} = parse_time(seed_time_raw)

    %{
      last_name: last_name,
      first_name: first_name,
      usa_swimming_id: if(usa_id == "", do: nil, else: usa_id),
      dob: dob,
      age: age,
      gender: gender,
      event_code: event_code,
      event_number: event_number,
      event_name: event_name,
      seed_time: seed_time,
      seed_time_seconds: seed_time_seconds,
      course: course,
      stroke: stroke,
      distance: distance
    }
  end

  # --- Helpers ---

  defp slice(str, start, len) do
    str |> String.slice(start, len) |> String.trim()
  end

  defp split_name(name) do
    case String.split(name, ",", parts: 2) do
      [last, first] -> {String.trim(last), String.trim(first) |> String.split(" ") |> hd()}
      [single] -> {String.trim(single), ""}
    end
  end

  defp parse_date(str) do
    case str do
      <<m::binary-size(2), d::binary-size(2), y::binary-size(4)>> ->
        case Date.new(String.to_integer(y), String.to_integer(m), String.to_integer(d)) do
          {:ok, date} -> date
          _ -> nil
        end
      _ -> nil
    end
  end

  defp parse_int(str) do
    case Integer.parse(String.trim(str)) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp parse_time(raw) do
    trimmed = String.trim(raw)

    cond do
      trimmed == "" or trimmed == "NTY" or trimmed == "NT" ->
        {"NT", nil}

      String.contains?(trimmed, ":") ->
        [mins, secs] = String.split(trimmed, ":")
        seconds = String.to_integer(mins) * 60 + String.to_float(secs)
        {trimmed, seconds}

      true ->
        case Float.parse(trimmed) do
          {seconds, _} -> {trimmed, seconds}
          :error -> {trimmed, nil}
        end
    end
  end

  defp extract_time_and_course(time_area) do
    trimmed = String.trim(time_area)

    cond do
      trimmed == "" or trimmed == "NTY" ->
        {"NT", "Y"}

      String.ends_with?(trimmed, "Y") or String.ends_with?(trimmed, "L") or String.ends_with?(trimmed, "S") ->
        course = String.last(trimmed)
        time = String.slice(trimmed, 0, String.length(trimmed) - 1)
        {time, course}

      true ->
        {trimmed, "Y"}
    end
  end

  defp decode_event(code) do
    # SD3 event code: DDSS — first 2 chars = distance, last 2 chars = stroke
    # Distance: " 5"=50, "10"=100, "20"=200, "50"=500
    # Stroke: "01"=Free, "02"=Back, "03"=Breast, "04"=Fly, "05"=IM
    padded = String.pad_leading(code, 4)

    distance =
      case String.slice(padded, 0, 2) |> String.trim() do
        "5" -> 50
        "10" -> 100
        "20" -> 200
        "50" -> 500
        d -> parse_int(d) || 0
      end

    stroke =
      case String.slice(padded, 2, 2) do
        "01" -> "Free"
        "02" -> "Back"
        "03" -> "Breast"
        "04" -> "Fly"
        "05" -> "IM"
        _ -> "Unknown"
      end

    {distance, stroke}
  end
end
