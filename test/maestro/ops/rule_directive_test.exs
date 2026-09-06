defmodule Maestro.Ops.RuleDirectiveTest do
  @moduledoc """
  Rule direction must survive legacy imports and repeated output generation.
  These examples pin the user-visible instruction rather than parser internals.
  """

  use ExUnit.Case, async: true

  alias Maestro.Ops.RuleDirective

  describe "legacy instruction wording" do
    test "recognizes explicit prohibitions without guessing from later prose" do
      assert RuleDirective.infer("**Never** deploy without approval") == :forbid
      assert RuleDirective.infer("- Avoid: raw database access") == :forbid
      assert RuleDirective.infer("Do not swallow failures") == :forbid

      assert RuleDirective.infer("When corrected, capture the lesson. Never lose the correction.") ==
               :require
    end

    test "recognizes requirements and preferences" do
      assert RuleDirective.infer("**Always** validate generated code") == :require
      assert RuleDirective.infer("MUST validate generated code") == :require
      assert RuleDirective.infer("- Prefer: platform primitives") == :prefer
    end

    test "removes an outer bold marker without leaving formatting debris" do
      assert RuleDirective.parse("- **NEVER create memory files.**") == %{
               content: "create memory files.",
               directive: :forbid
             }
    end
  end

  describe "generated instructions" do
    test "round trips without reversing or duplicating direction markers" do
      examples = [
        {"**Never** deploy without approval", :forbid, :must,
         "**NEVER** deploy without approval"},
        {"**Always** validate generated code", :require, :must,
         "**ALWAYS** validate generated code"},
        {"- Prefer: platform primitives", :prefer, :prefer, "- Prefer: platform primitives"},
        {"Avoid raw database access", :forbid, :should, "- Avoid: raw database access"}
      ]

      for {source, directive, severity, expected} <- examples do
        generated = RuleDirective.markdown_line(source, directive, severity)

        assert generated == expected

        assert RuleDirective.markdown_line(
                 generated,
                 RuleDirective.infer(generated),
                 severity
               ) == expected
      end
    end

    test "compact exports retain prohibition semantics" do
      assert RuleDirective.compact_line("Never deploy", :forbid, :must) ==
               "MUST NOT: deploy"

      assert RuleDirective.compact_line("Avoid page-specific styles", :forbid, :prefer) ==
               "PREFER NOT: page-specific styles"
    end
  end
end
