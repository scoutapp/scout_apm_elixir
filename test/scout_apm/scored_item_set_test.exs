defmodule ScoutApm.ScoredItemSetTest do
  use ExUnit.Case, async: true
  alias ScoutApm.ScoredItemSet

  describe "size/1" do
    test "a new set is size 0" do
      assert 0 == ScoredItemSet.size(ScoredItemSet.new())
    end

    test "a set with an item is size 1" do
      assert 1 == ScoredItemSet.size(
        ScoredItemSet.new()
        |> ScoredItemSet.absorb(item())
      )
    end

    test "a set with lots of items caps at max_size" do
      set = (1..100)
            |> Enum.reduce(ScoredItemSet.new(),
                           fn i, set -> ScoredItemSet.absorb(set, item(i, "key#{i}")) end)

      assert 10 == ScoredItemSet.size(set)
    end
  end

  describe "absorb/2" do
    test "absorbing an item with the same name has the highest score stay" do
      assert [{_, {"key", 20, _}}] =
        ScoredItemSet.to_list(
          ScoredItemSet.new()
          |> ScoredItemSet.absorb(item(10, "key"))
          |> ScoredItemSet.absorb(item(20, "key"))
          |> ScoredItemSet.absorb(item(0, "key"))
          |> ScoredItemSet.absorb(item(15, "key"))
        )
    end

    test "absorbing different items doesn't cause competition" do
      assert [
        {_, {"key1", 10, _}},
        {_, {"key2", 20, _}},
        {_, {"key3", 05, _}},
        {_, {"key4", 15, _}},
      ] =
        ScoredItemSet.to_list(
          ScoredItemSet.new()
          |> ScoredItemSet.absorb(item(10, "key1"))
          |> ScoredItemSet.absorb(item(20, "key2"))
          |> ScoredItemSet.absorb(item(05, "key3"))
          |> ScoredItemSet.absorb(item(15, "key4"))
        )
    end

    test "with a full set, low scored items don't get added" do
      assert [
        {_, {"key01", 01, _}},
        {_, {"key02", 02, _}},
        {_, {"key03", 03, _}},
        {_, {"key04", 04, _}},
        {_, {"key05", 05, _}},
        {_, {"key06", 06, _}},
        {_, {"key07", 07, _}},
        {_, {"key08", 08, _}},
        {_, {"key09", 09, _}},
        {_, {"key10", 10, _}},
      ] =
        ScoredItemSet.to_list(
          ScoredItemSet.new()
          |> ScoredItemSet.absorb(item(01, "key01"))
          |> ScoredItemSet.absorb(item(02, "key02"))
          |> ScoredItemSet.absorb(item(03, "key03"))
          |> ScoredItemSet.absorb(item(04, "key04"))
          |> ScoredItemSet.absorb(item(05, "key05"))
          |> ScoredItemSet.absorb(item(06, "key06"))
          |> ScoredItemSet.absorb(item(07, "key07"))
          |> ScoredItemSet.absorb(item(08, "key08"))
          |> ScoredItemSet.absorb(item(09, "key09"))
          |> ScoredItemSet.absorb(item(10, "key10"))

          |> ScoredItemSet.absorb(item(0, "key11"))
        )
    end

    test "with a full set, high scored items evict another item" do
      assert [
        {_, {"key02", 02, _}},
        {_, {"key03", 03, _}},
        {_, {"key04", 04, _}},
        {_, {"key05", 05, _}},
        {_, {"key06", 06, _}},
        {_, {"key07", 07, _}},
        {_, {"key08", 08, _}},
        {_, {"key09", 09, _}},
        {_, {"key10", 10, _}},
        {_, {"key11", 20, _}},
      ] =
        ScoredItemSet.to_list(
          ScoredItemSet.new()
          |> ScoredItemSet.absorb(item(01, "key01"))
          |> ScoredItemSet.absorb(item(02, "key02"))
          |> ScoredItemSet.absorb(item(03, "key03"))
          |> ScoredItemSet.absorb(item(04, "key04"))
          |> ScoredItemSet.absorb(item(05, "key05"))
          |> ScoredItemSet.absorb(item(06, "key06"))
          |> ScoredItemSet.absorb(item(07, "key07"))
          |> ScoredItemSet.absorb(item(08, "key08"))
          |> ScoredItemSet.absorb(item(09, "key09"))
          |> ScoredItemSet.absorb(item(10, "key10"))

          |> ScoredItemSet.absorb(item(20, "key11"))
        )
    end
  end

  def item(score \\ 10, key \\ "key") do
    {{:score, score, key}, {key, score, "other stuff value"}}
  end
end
