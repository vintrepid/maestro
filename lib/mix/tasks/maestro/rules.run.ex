defmodule Mix.Tasks.Maestro.Rules.Run do
  @moduledoc """
  Apply a per-rule action to a selected set of rules.

  ## Usage

      # Diagnose one rule
      mix maestro.rules.run --action diagnose --id <uuid>

      # Diagnose all retired rules in one library
      mix maestro.rules.run --action diagnose --selector retired --library ash

      # Re-triage dangling-linter rules
      mix maestro.rules.run --action re_triage --selector dangling_linters

  Actions: `diagnose` (read-only), `re_triage` (mutates).
  Selectors: `ids`, `retired`, `dangling_linters`.
  """

  use Mix.Task
  alias Maestro.Ops.Rules.{Inspector, Runner}

  @shortdoc "Run a per-rule action over a selected set"

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          action: :string,
          selector: :string,
          id: :string,
          library: :string,
          verdict: :string
        ]
      )

    action = parse_action(opts[:action])
    ids = select(opts)

    IO.puts("")
    IO.puts("Running #{action}/1 on #{length(ids)} rule(s)…")

    result = Runner.run(ids, action)
    render(action, result, opts)
  end

  # --- Selector ---

  defp select(opts) do
    case opts[:id] do
      nil -> select_by(opts[:selector] || "retired", opts)
      id -> [id]
    end
  end

  defp select_by("retired", opts), do: Inspector.retired_ids(opts[:library])
  defp select_by("dangling_linters", _opts), do: Inspector.dangling_linter_ids()

  defp select_by(other, _opts) do
    Mix.shell().error("Unknown selector: #{other}")
    exit({:shutdown, 1})
  end

  # --- Action parse ---

  defp parse_action(nil) do
    Mix.shell().error("--action is required")
    exit({:shutdown, 1})
  end

  defp parse_action(name) do
    atom = String.to_atom(name)

    unless function_exported?(Maestro.Ops.Rules.Action, atom, 1) do
      Mix.shell().error("Unknown action: #{name}")
      exit({:shutdown, 1})
    end

    atom
  end

  # --- Render ---

  defp render(:diagnose, %{ok: results, errors: errors}, opts) do
    filter = opts[:verdict] && String.to_atom(opts[:verdict])

    visible =
      case filter do
        nil -> results
        v -> Enum.filter(results, &(&1.verdict == v))
      end

    IO.puts("")
    IO.puts("Verdict distribution:")

    results
    |> Enum.group_by(& &1.verdict)
    |> Enum.sort_by(fn {_, rs} -> -length(rs) end)
    |> Enum.each(fn {v, rs} ->
      IO.puts("  #{String.pad_trailing(to_string(v), 16)} #{length(rs)}")
    end)

    if filter do
      IO.puts("")
      IO.puts("Showing #{length(visible)} rule(s) with verdict=#{filter}:")
      IO.puts("")

      Enum.each(visible, fn r ->
        IO.puts(
          "  #{String.slice(r.id, 0, 8)}  [was: #{r.current_status}/#{r.current_reason || "-"}] → #{r.triage_decision}"
        )

        IO.puts("    #{r.content_preview}")
      end)
    end

    if errors != [], do: IO.puts("\nErrors: #{length(errors)}")
    IO.puts("")
  end

  defp render(:re_triage, %{ok: results, errors: errors}, _opts) do
    transitions =
      Enum.group_by(results, fn r -> {r.from, r.to} end)

    IO.puts("")
    IO.puts("Status transitions:")

    Enum.each(transitions, fn {{from, to}, rs} ->
      IO.puts("  #{from} → #{to}: #{length(rs)}")
    end)

    if errors != [], do: IO.puts("\nErrors: #{length(errors)}")
    IO.puts("")
  end

  defp render(_action, result, _opts) do
    IO.inspect(result, limit: :infinity)
  end
end
