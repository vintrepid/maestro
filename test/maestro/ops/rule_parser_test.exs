defmodule Maestro.Ops.RuleParserTest do
  @moduledoc """
  Categorization is the ladder Triage stands on. If the categorizer
  sweeps agent-behavior rules into `:architecture`, CLAUDE.md
  generation can't separate them from domain rules, and the user
  loses the "general guidelines for AIs" scope. Pinning the
  content-aware categorizer here.
  """
  use ExUnit.Case, async: true

  alias Maestro.Ops.RuleParser

  describe "categorize_by_content/2 — agent_behavior" do
    test "rules about correction reflex land in :agent_behavior, not :architecture" do
      content = ~s(**Always** say "Aha" instead of "You're right" when the user corrects you.)
      assert RuleParser.categorize_by_content(content) == :agent_behavior
    end

    test "rules about deploy discipline land in :agent_behavior" do
      content =
        "Never run mix maestro.deploy without an explicit user instruction for the specific change."

      assert RuleParser.categorize_by_content(content) == :agent_behavior
    end

    test "rules about response style / succinctness land in :agent_behavior" do
      content = "Default response style is succinct. Expand at decision points only."
      assert RuleParser.categorize_by_content(content) == :agent_behavior
    end

    test "rules about narration-before-action land in :agent_behavior" do
      content =
        "Before any non-trivial tool call, narrate the why briefly in user-facing text."

      assert RuleParser.categorize_by_content(content) == :agent_behavior
    end

    test "tool-first reflex rules land in :agent_behavior" do
      content = "Always fix the tool first, then run the tool. Never do one-off manual work."
      assert RuleParser.categorize_by_content(content) == :agent_behavior
    end
  end

  describe "categorize_by_content/2 — domain rules still route correctly" do
    test "Ash content lands in :ash" do
      assert RuleParser.categorize_by_content("Use Ash.Changeset.for_update/3 for updates.") == :ash
    end

    test "LiveView content lands in :liveview" do
      assert RuleParser.categorize_by_content("Use handle_event/3 to handle phx- events.") == :liveview
    end

    test "HEEx content lands in :heex" do
      assert RuleParser.categorize_by_content("Use ~H\" for HEEx templates.") == :heex
    end

    test "Tailwind/CSS content lands in :css" do
      assert RuleParser.categorize_by_content("Use DaisyUI component classes instead of tailwind utilities.") == :css
    end
  end

  describe "categorize_by_content/2 — residual fallback" do
    test "genuinely architectural content still lands in :architecture" do
      content = "Split the module into functional core and imperative shell boundaries."
      assert RuleParser.categorize_by_content(content) == :architecture
    end
  end
end
