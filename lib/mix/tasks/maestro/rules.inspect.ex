defmodule Mix.Tasks.Maestro.Rules.Inspect do
  @moduledoc """
  Inspect the shape and health of the rules DB.

  ## Usage

      mix maestro.rules.inspect                                  # overall summary
      mix maestro.rules.inspect --library ash                    # drill into one library
      mix maestro.rules.inspect --library ash --reason "Too short to be actionable"
      mix maestro.rules.inspect --id <uuid>                      # drill into one rule

  With `--reason`, prints every rule in that bucket (not a sample).
  Use `"(none)"` as the reason value to see rules retired without a reason.

  This task is **read-only selection + display**. Per-rule actions (diagnose,
  approve, retire, re-triage, etc.) live on `Maestro.Ops.Rules.Action`. A
  separate task runner applies an action to a selected set.
  """

  use Mix.Task
  alias Maestro.Ops.Rules.Inspector

  @shortdoc "Summaries and buckets for rules DB"

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args, strict: [library: :string, reason: :string, id: :string])

    cond do
      opts[:id] -> drill_rule(opts[:id])
      opts[:library] && opts[:reason] -> drill_bucket(opts[:library], opts[:reason])
      opts[:library] -> library_view(opts[:library])
      true -> overview()
    end
  end

  # --- Views ---

  defp overview do
    IO.puts("")
    IO.puts(bold("Per-library status:"))

    print_table(
      ["library", "total", "appr", "prop", "retd", "lint", "anti"],
      Enum.map(Inspector.per_library_status(), fn r ->
        [
          r.library,
          r.total,
          r.approved,
          r.proposed,
          r.retired,
          r.linter,
          r.anti_pattern
        ]
      end)
    )

    IO.puts("")
    IO.puts(bold("Retired reasons (all libraries):"))

    Inspector.retired_reason_buckets()
    |> Enum.each(fn %{reason: r, count: c} ->
      IO.puts("  #{String.pad_trailing(to_string(r || "(none)"), 50)} #{c}")
    end)

    IO.puts("")
    IO.puts(bold("Linter health:"))

    %{
      total: total,
      linter_status: lint_status,
      with_lint_pattern: lpat,
      with_lint_config: lcfg,
      with_fix_type: fix,
      dangling_lint_metadata: dangling
    } = Inspector.linter_health()

    IO.puts("  total rules:            #{total}")
    IO.puts("  :linter status:         #{lint_status}")
    IO.puts("  with lint_pattern:      #{lpat}")
    IO.puts("  with lint_config:       #{lcfg}")
    IO.puts("  with fix_type:          #{fix}")
    IO.puts("  dangling lint metadata: #{dangling}  (lint_* set but status != :linter)")
    IO.puts("")
  end

  defp library_view(lib) do
    row =
      Enum.find(Inspector.per_library_status(), %{}, fn r -> r.library == lib end)

    if row == %{} do
      Mix.shell().error("Unknown library: #{lib}")
      exit({:shutdown, 1})
    end

    IO.puts("")
    IO.puts(bold("Library: #{lib}"))
    IO.puts("  total: #{row.total}")
    IO.puts("  approved: #{row.approved}   proposed: #{row.proposed}   retired: #{row.retired}")
    IO.puts("  linter: #{row.linter}   anti-pattern: #{row.anti_pattern}")

    IO.puts("")
    IO.puts(bold("Retired reasons in #{lib}:"))

    Inspector.retired_reason_buckets(lib)
    |> Enum.each(fn %{reason: r, count: c} ->
      IO.puts("  #{String.pad_trailing(to_string(r || "(none)"), 50)} #{c}")
    end)

    IO.puts("")
    IO.puts(bold("Samples (5 per bucket):"))

    Inspector.sample_retired(lib, 5)
    |> Enum.each(fn {reason, rs} ->
      IO.puts("")
      IO.puts("  [#{reason || "(none)"}]")

      Enum.each(rs, fn r ->
        IO.puts("    #{short_id(r.id)}  #{preview(r.content)}")
      end)
    end)

    IO.puts("")
  end

  defp drill_bucket(lib, reason) do
    reason = if reason == "(none)", do: nil, else: reason
    rows = Inspector.drill_bucket(lib, reason)

    IO.puts("")
    IO.puts(bold("#{lib} / #{reason || "(none)"}: #{length(rows)} rules"))
    IO.puts("")

    Enum.each(rows, fn r ->
      IO.puts("#{short_id(r.id)}")
      IO.puts("  #{r.content |> String.replace(~r/\n+/, "\n  ") |> String.slice(0, 400)}")
      IO.puts("")
    end)
  end

  defp drill_rule(id) do
    case Inspector.drill_rule(id) do
      nil ->
        Mix.shell().error("No rule with id=#{id}")
        exit({:shutdown, 1})

      r ->
        IO.puts("")
        IO.puts(bold("Rule #{r.id}"))
        IO.puts("  library:      #{r.library}")
        IO.puts("  status:       #{r.status}")
        IO.puts("  severity:     #{r.severity}   category: #{r.category}")
        IO.puts("  retired_rsn:  #{r.retired_reason || "-"}")
        IO.puts("  superseded:   #{r.superseded_by_id || "-"}")
        IO.puts("  source:       #{r.source_project_slug || "-"} @ #{r.source_commit || "-"}")
        IO.puts("  lint_pattern: #{r.lint_pattern || "-"}")
        IO.puts("  fix_type:     #{r.fix_type || "-"}")
        IO.puts("  inserted:     #{r.inserted_at}")
        IO.puts("  retired_at:   #{r.retired_at || "-"}")
        IO.puts("")
        IO.puts("CONTENT:")
        IO.puts(r.content)
        IO.puts("")
    end
  end

  # --- Formatting ---

  defp bold(s), do: IO.ANSI.bright() <> s <> IO.ANSI.reset()

  defp preview(s), do: s |> String.replace(~r/\n+/, " ") |> String.slice(0, 110)

  defp short_id(id), do: String.slice(id, 0, 8)

  defp print_table(headers, rows) do
    widths =
      headers
      |> Enum.with_index()
      |> Enum.map(fn {h, i} ->
        max(
          String.length(h),
          rows |> Enum.map(&String.length(to_string(Enum.at(&1, i)))) |> Enum.max(fn -> 0 end)
        )
      end)

    pad = fn parts ->
      parts
      |> Enum.with_index()
      |> Enum.map(fn {part, i} ->
        w = Enum.at(widths, i)

        if i == 0,
          do: String.pad_trailing(to_string(part), w),
          else: String.pad_leading(to_string(part), w)
      end)
      |> Enum.join("  ")
    end

    IO.puts("  " <> pad.(headers))
    Enum.each(rows, fn row -> IO.puts("  " <> pad.(row)) end)
  end
end
