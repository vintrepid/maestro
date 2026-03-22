defmodule Maestro.Ops.Rules.Fixer do
  @moduledoc """
  Applies rule fixes to source files using Igniter for AST-based code modification.

  Each fix_type maps to a different Igniter strategy. The Rule carries the fix
  configuration — the fixer just executes it.
  """

  alias Igniter.Code.{Function, Common}

  @doc """
  Applies a rule's fix to a module. Returns {:ok, igniter} or {:error, reason}.
  """
  def fix_it(igniter, rule, module_name) do
    case rule.fix_type do
      :add_callback -> add_callback(igniter, module_name, rule.fix_target, rule.fix_template)
      :add_to_mount -> add_to_mount(igniter, module_name, rule.fix_template)
      :extract_css -> {:ok, igniter}  # CSS extraction is text-level, handled separately
      :replace_pattern -> {:ok, igniter}  # Complex, needs per-case handling
      :remove_pattern -> {:ok, igniter}  # Complex, needs per-case handling
      :wrap_pattern -> {:ok, igniter}
      nil -> {:error, "No fix_type set on rule"}
      _ -> {:error, "Unknown fix_type"}
    end
  end

  @doc """
  Applies all fixable rule violations on a page. Returns {:ok, igniter}.
  """
  def fix_page(igniter, page_result, rules_by_id) do
    fixable_findings =
      page_result.findings
      |> Enum.reject(& &1.pass?)
      |> Enum.filter(fn f ->
        rule = rules_by_id[f.rule_id]
        rule && rule.fix_type in [:add_callback]
      end)

    Enum.reduce(fixable_findings, {:ok, igniter}, fn finding, {:ok, ign} ->
      rule = rules_by_id[finding.rule_id]
      fix_it(ign, rule, page_result.module)
    end)
  end

  # -- Fix strategies --

  # Add a callback function to a module if it doesn't exist.
  defp add_callback(igniter, module_name, target, template) do
    {func_name, arity} = parse_func_ref(target)

    Igniter.Project.Module.find_and_update_module(igniter, module_name, fn zipper ->
      case Function.move_to_def(zipper, func_name, arity) do
        {:ok, _} ->
          # Already exists
          {:ok, zipper}

        :error ->
          # Add the callback at the end of the module body
          {:ok, Common.add_code(zipper, template, placement: :after)}
      end
    end)
  end

  # Add code to the mount function body.
  defp add_to_mount(igniter, module_name, template) do
    Igniter.Project.Module.find_and_update_module(igniter, module_name, fn zipper ->
      case Function.move_to_def(zipper, :mount, 3) do
        {:ok, zipper} ->
          case Common.move_to_do_block(zipper) do
            {:ok, zipper} ->
              {:ok, Common.add_code(zipper, template, placement: :before)}
            _ ->
              {:ok, zipper}
          end

        :error ->
          # No mount function, skip
          {:ok, zipper}
      end
    end)
  end

  # -- Helpers --

  defp parse_func_ref(target) when is_binary(target) do
    case String.split(target, "/") do
      [name, arity] -> {String.to_atom(name), String.to_integer(arity)}
      [name] -> {String.to_atom(name), :any}
    end
  end

  defp parse_func_ref(_), do: {:unknown, :any}
end
