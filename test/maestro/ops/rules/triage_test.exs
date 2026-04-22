defmodule Maestro.Ops.Rules.TriageTest do
  @moduledoc """
  The Triage decision is a pure function — no DB, no IO. Pinning its
  verdict table here because the curator pipeline uses it to decide
  which rules land in CLAUDE.md (via :approved) versus which sit in
  the human-curation queue (:proposed).

  Regression rule of thumb: a rule should land in :approved *only* if
  it explicitly carries a severity marker (Always/Must, Never/FORBIDDEN,
  Avoid) or comes from a trusted upstream source with real substance.
  Everything else belongs in :proposed, not :approved.
  """
  use ExUnit.Case, async: true

  alias Maestro.Ops.Rules.Triage

  describe "decide/2 — severity markers" do
    test "**Always** auto-approves regardless of length" do
      assert %{status: :approved} = Triage.decide("**Always** commit before building", nil)
    end

    test "**Must** is treated the same as **Always**" do
      assert %{status: :approved} = Triage.decide("**Must** validate at system boundaries", nil)
    end

    test "**Never** auto-approves" do
      assert %{status: :approved} = Triage.decide("**Never** swallow errors with a log-and-continue", nil)
    end

    test "**FORBIDDEN** is treated the same as **Never**" do
      assert %{status: :approved} = Triage.decide("**FORBIDDEN** to push --force to main", nil)
    end

    test "**Avoid** also auto-approves" do
      assert %{status: :approved} = Triage.decide("**Avoid** mocking the database in integration tests", nil)
    end
  end

  describe "decide/2 — fall-through is :proposed, never auto-:approved" do
    test "unmarked short rule lands in :proposed, not :retired" do
      # This is the specific un-retire you made: short ≠ bad.
      decision = Triage.decide("Commit before deploy.", nil)
      assert decision.status == :proposed
    end

    test "unmarked long rule still lands in :proposed" do
      content =
        "Always think carefully about error handling when designing new APIs. " <>
          "Consider what failure modes can occur and how callers should react to them. " <>
          "This is a long prose paragraph without any explicit severity markers."

      decision = Triage.decide(content, nil)
      assert decision.status == :proposed
    end
  end

  describe "decide/2 — trusted sources" do
    test "ash source with enough substance (>200 chars) auto-approves" do
      long_ash_rule =
        "Ash actions should be defined on the resource, not in a separate service module. " <>
          "Callers invoke them through the code interface. Validations and changes compose " <>
          "through the action; never re-implement them in calling code. Trust the resource."

      assert String.length(long_ash_rule) > 200, "test string must exceed the 200-char gate"
      assert %{status: :approved} = Triage.decide(long_ash_rule, "ash")
    end

    test "ash source below the 200-char substance gate stays :proposed" do
      # The gate exists to keep trivia from auto-approving even from trusted sources.
      short_ash_rule = "Use Ash actions for mutations."
      assert %{status: :proposed} = Triage.decide(short_ash_rule, "ash")
    end

    test "untrusted source with same substance stays :proposed" do
      long_rule =
        "Some generic advice about code. " <>
          "It is a substantial paragraph, but has no explicit severity marker " <>
          "and does not come from a trusted upstream source that we auto-approve."

      assert %{status: :proposed} = Triage.decide(long_rule, "some-random-source")
    end
  end

  describe "decide/2 — retire reasons still fire" do
    test "obsolete workflow content gets retired, not proposed" do
      # Keep the retire patterns honest — things like old bundle-tracking
      # commands should still be filtered out, not parked in :proposed.
      content = "Run mix session.capacity to check availability before starting."
      assert %{status: :retired, reason: _} = Triage.decide(content, nil)
    end

    test "structural prose (README-style) gets retired" do
      content = "**docs/** - Historical design notes and architecture records"
      assert %{status: :retired, reason: _} = Triage.decide(content, nil)
    end
  end
end
