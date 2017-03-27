defmodule ScoutApm.ScoredItemSet do
  @moduledoc """
  A capped set type that has a few rules on inclusion.

  When you add an item, it must be a tuple of shape: {{:score, integer, key}, item}

  Where the key uniquely identifies the item, as a string. The score is a
  unitless relative "value" of this item, and then the item itself can be any
  structure

  Only the highest score of each key is kept, no duplicates, even if the set has "room" for it.

  Only the highest scores will be kept when at capacity. Adding a new element
  may or may result in the new item evicting an old one, or being simply
  dropped, based on the comparison of the scores.
  """

  @type t :: %__MODULE__{
    options: __MODULE__.options,
    data: %{any() => scored_item}
  }

  @type options :: %{
    max_count: pos_integer()
  }

  @type key :: String.t
  @type score :: {:score, number(), key}
  @type scored_item :: {score, any()}

  defstruct [
    :options,
    :data,
  ]

  @default_max_count 10

  @spec new() :: t
  def new() do
    %__MODULE__{
      options: %{
        max_count: @default_max_count
      },
      data: %{}
    }
  end

  @spec set_max_count(t, pos_integer()) :: t
  def set_max_count(%__MODULE__{} = set, max_count) do
    %{set | options: %{set.options | max_count: max_count}}
  end

  @spec size(t) :: non_neg_integer()
  def size(%__MODULE__{} = set) do
    Enum.count(set.data)
  end

  @spec absorb(t, scored_item) :: t
  def absorb(%__MODULE__{} = set, {{_, score, key}, _} = scored_item) do
    case Map.fetch(set.data, key) do
      # If the item exists, compare the new vs old scored_items and the winner
      # gets put into the data map. Size of the data map doesn't change.
      {:ok, {{_,existing_score,_},_} = existing_scored_item} ->
        winner = if existing_score < score do
          scored_item
        else
          existing_scored_item
        end
        %{set | data: %{set.data | key => winner}}

      # If this key doesn't yet exist, then we simply add it if there's room
      # or if not, we have to figure out if it's high enough score to evict
      # another, and then do the eviction
      :error ->
        if size(set) < set.options.max_count do
          %{set | data: set.data
                          |> Map.put(key, scored_item)}
        else
          absorb_at_capacity(set, scored_item)
        end
    end
  end

  @spec to_list(t) :: list(scored_item)
  def to_list(%__MODULE__{} = set) do
    Enum.map(set.data, fn {_, v} -> v end)
  end

  @spec absorb_at_capacity(t, scored_item) :: t
  defp absorb_at_capacity(%__MODULE__{} = set, {{:score, score, key}, _} = scored_item) do
    {_, {{_, low_score, low_key}, _}} =
      Enum.min_by(set.data, fn {_key, {{_, s, _}, _}} -> s end)

    if score < low_score do
      # This score was too low to break into the set, so no update is needed.
      set
    else
      # This score is higher than the lowest in the set, so we'll evict the
      # lowest, and replace it with this one.
      %{set | data: set.data
        |> Map.delete(low_key)
        |> Map.put(key, scored_item)}
    end
  end
end
