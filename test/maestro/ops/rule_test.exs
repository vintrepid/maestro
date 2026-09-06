defmodule Maestro.Ops.RuleTest do
  @moduledoc """
  Rule actions are the compatibility boundary for legacy clients that only send
  content and for current clients that send an explicit directive.
  """

  use Maestro.DataCase, async: true

  alias Maestro.Ops.Rule
  alias Maestro.Ops.RuleParser

  test "create infers a missing directive from explicit legacy wording" do
    rule =
      Rule.create!(
        %{content: "Never deploy without approval", category: :deployment, severity: :must},
        authorize?: false
      )

    assert rule.directive == :forbid
  end

  test "an explicit directive is authoritative" do
    rule =
      Rule.create!(
        %{
          content: "Treat the quoted prohibition as documentation",
          category: :testing,
          directive: :forbid,
          severity: :should
        },
        authorize?: false
      )

    assert rule.directive == :forbid
  end

  test "changing content does not silently overwrite the stored directive" do
    rule =
      Rule.create!(
        %{content: "Always validate generated code", category: :testing, severity: :must},
        authorize?: false
      )

    updated =
      Rule.update!(rule, %{content: "Never write invalid generated code"}, authorize?: false)

    assert updated.directive == :require
    assert updated.content_hash == RuleParser.content_hash(updated.content, :require)
    refute updated.content_hash == rule.content_hash
  end

  test "changing direction updates the rule's semantic identity" do
    rule =
      Rule.create!(
        %{content: "Deploy after review", category: :deployment, severity: :should},
        authorize?: false
      )

    updated = Rule.update!(rule, %{directive: :forbid}, authorize?: false)

    assert updated.content_hash == RuleParser.content_hash(updated.content, :forbid)
    refute updated.content_hash == rule.content_hash
  end
end
