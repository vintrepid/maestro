defmodule Maestro.Ops.Rules.Dedup do
  @moduledoc """
  Pure deduplication logic. Checks content against existing hashes/content.
  No DB access — caller provides the existing data.
  """

  alias Maestro.Ops.RuleParser

  @doc """
  Check if a rule is a duplicate.
  Returns :new, :exact_duplicate, or :near_duplicate.
  """
  @spec check(String.t(), String.t(), MapSet.t(), [String.t()]) :: :new | :exact_duplicate | :near_duplicate
  def check(content, content_hash, existing_hashes, existing_normalized) do
    cond do
      MapSet.member?(existing_hashes, content_hash) ->
        :exact_duplicate

      near_duplicate?(content, existing_normalized) ->
        :near_duplicate

      true ->
        :new
    end
  end

  @doc "Check if content is a near-duplicate of any existing normalized content."
  def near_duplicate?(content, existing_normalized, threshold \\ 0.85) do
    normalized = RuleParser.normalize(content)
    norm_len = String.length(normalized)

    Enum.any?(existing_normalized, fn existing ->
      existing_len = String.length(existing)

      cond do
        # Prefix match: one is the start of the other (quality gate appends "why" clauses)
        norm_len > 20 and String.starts_with?(existing, normalized) -> true
        existing_len > 20 and String.starts_with?(normalized, existing) -> true

        # Jaro similarity for longer content
        norm_len > 80 -> String.jaro_distance(normalized, existing) > threshold

        true -> false
      end
    end)
  end
end
