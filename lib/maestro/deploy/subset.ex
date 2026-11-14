defmodule Maestro.Deploy.Subset do
  @moduledoc "Exports database to SQL seed file for production."
  @output_path "priv/repo/seeds/prod_seed.sql"

  @spec export() :: {:ok, [{String.t(), non_neg_integer()}]}
  def export do
    File.mkdir_p!(Path.dirname(@output_path))
    file = File.open!(@output_path, [:write])

    try do
      IO.write(file, "-- Production seed data\n")
      IO.write(file, "-- Generated: #{DateTime.to_iso8601(DateTime.utc_now())}\n\n")
      tables = discover_tables()

      stats =
        for table <- tables do
          count = export_table(file, table)
          {table, count}
        end

      IO.puts("Exported to #{@output_path}:")
      for {table, count} <- stats, do: IO.puts("  #{table}: #{count} rows")
      {:ok, stats}
    after
      File.close(file)
    end
  end

  defp discover_tables do
    {:ok, result} =
      Maestro.Repo.query(
        "SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename NOT LIKE 'schema_%' AND tablename != 'oban_jobs' AND tablename != 'oban_peers' ORDER BY tablename"
      )

    List.flatten(result.rows)
  end

  defp export_table(file, table) do
    IO.write(file, "\n-- #{table}\n")
    {:ok, result} = Maestro.Repo.query("SELECT * FROM \"#{table}\"")

    if result.num_rows == 0 do
      IO.write(file, "-- (no rows)\n")
      0
    else
      columns = Enum.join(result.columns, ", ")
      IO.write(file, "COPY #{table} (#{columns}) FROM stdin;\n")

      for row <- result.rows do
        line = row |> Enum.map(&format_value/1) |> Enum.join("\t")
        IO.write(file, line <> "\n")
      end

      IO.write(file, "\\.\n")
      result.num_rows
    end
  end

  defp format_value(nil), do: "\\N"
  defp format_value(true), do: "t"
  defp format_value(false), do: "f"
  defp format_value(%Date{} = d), do: Date.to_iso8601(d)
  defp format_value(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp format_value(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_iso8601(ndt)

  defp format_value(<<_::128>> = bin) do
    if String.printable?(bin), do: escape(bin), else: Ecto.UUID.cast!(bin)
  end

  defp format_value(v) when is_binary(v), do: escape(v)
  defp format_value(v) when is_integer(v), do: Integer.to_string(v)
  defp format_value(v) when is_float(v), do: Float.to_string(v)
  defp format_value(v) when is_atom(v), do: Atom.to_string(v)
  defp format_value(%{} = map), do: Jason.encode!(map)

  defp format_value(v) when is_list(v) do
    inner =
      v
      |> Enum.map(fn
        el when is_map(el) -> ~s["] <> String.replace(Jason.encode!(el), ~s["], ~s[\\"]) <> ~s["]
        el when is_binary(el) -> ~s["] <> String.replace(el, ~s["], ~s[\\"]) <> ~s["]
        el -> to_string(el)
      end)
      |> Enum.join(",")

    "{#{inner}}"
  end

  defp format_value(v), do: to_string(v)

  defp escape(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("\t", "\\t")
    |> String.replace("\n", "\\n")
    |> String.replace("\r", "\\r")
  end
end
