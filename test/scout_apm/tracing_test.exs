defmodule ScoutApm.TracingTest do
  use ExUnit.Case

  setup do
    ScoutApm.TestCollector.clear_messages()
    :ok
  end

  describe "deftransaction" do
    test "creates histograms with sensible defaults" do
      assert ScoutApm.TestTracing.add_one(1) == 2
      assert ScoutApm.TestTracing.add_one(1.0) == 2.0

      [%{BatchCommand: %{commands: commands1}}, %{BatchCommand: %{commands: commands2}}] =
        ScoutApm.TestCollector.messages()

      assert Enum.any?(commands1, fn command ->
               map = Map.get(command, :StartSpan)

               map &&
                 Map.get(map, :operation) ==
                   "Job/ScoutApm.TestTracing.add_one(integer) when is_integer(integer)"
             end)

      assert Enum.any?(commands2, fn command ->
               map = Map.get(command, :StartSpan)

               map &&
                 Map.get(map, :operation) ==
                   "Job/ScoutApm.TestTracing.add_one(number) when is_float(number)"
             end)
    end

    test "creates histograms with overridden type and name" do
      assert ScoutApm.TestTracing.add_two(1) == 3
      assert ScoutApm.TestTracing.add_two(1.0) == 3.0

      [%{BatchCommand: %{commands: commands1}}, %{BatchCommand: %{commands: commands2}}] =
        ScoutApm.TestCollector.messages()

      assert Enum.any?(commands1, fn command ->
               map = Map.get(command, :StartSpan)
               map && Map.get(map, :operation) == "Controller/test1"
             end)

      assert Enum.any?(commands2, fn command ->
               map = Map.get(command, :StartSpan)
               map && Map.get(map, :operation) == "Job/test2"
             end)
    end
  end

  describe "deftiming" do
    test "creates histograms with sensible defaults" do
      assert ScoutApm.TestTracing.add_three(1) == 4
      assert ScoutApm.TestTracing.add_three(1.0) == 4

      [%{BatchCommand: %{commands: commands1}}, %{BatchCommand: %{commands: commands2}}] =
        ScoutApm.TestCollector.messages()

      assert Enum.any?(commands1, fn command ->
               map = Map.get(command, :StartSpan)

               map &&
                 Map.get(map, :operation) ==
                   "Custom/ScoutApm.TestTracing.add_three(integer) when is_integer(integer)"
             end)

      assert Enum.any?(commands2, fn command ->
               map = Map.get(command, :StartSpan)

               map &&
                 Map.get(map, :operation) ==
                   "Custom/ScoutApm.TestTracing.add_three(number) when is_float(number)"
             end)
    end

    test "creates histograms with overridden type and name" do
      assert ScoutApm.TestTracing.add_four(1) == 5
      assert ScoutApm.TestTracing.add_four(1.0) == 5.0

      [%{BatchCommand: %{commands: commands1}}, %{BatchCommand: %{commands: commands2}}] =
        ScoutApm.TestCollector.messages()

      assert Enum.any?(commands1, fn command ->
               map = Map.get(command, :StartSpan)
               map && Map.get(map, :operation) == "Adding/add integers"
             end)

      assert Enum.any?(commands2, fn command ->
               map = Map.get(command, :StartSpan)
               map && Map.get(map, :operation) == "Controller/add floats"
             end)
    end
  end

  test "marks as error" do
    assert ScoutApm.TestTracing.add_one_with_error(2) == 3
    assert ScoutApm.TestTracing.add_one_with_error(2) == 3

    [%{BatchCommand: %{commands: commands1}}, %{BatchCommand: %{commands: commands2}}] =
      ScoutApm.TestCollector.messages()

    assert Enum.any?(commands1, fn command ->
             map = Map.get(command, :TagRequest)
             map && Map.get(map, :tag) == "error" && Map.get(map, :value) == "true"
           end)

    assert Enum.any?(commands2, fn command ->
             map = Map.get(command, :TagRequest)
             map && Map.get(map, :tag) == "error" && Map.get(map, :value) == "true"
           end)
  end

  test "marks as ignored" do
    assert ScoutApm.TestTracing.add_five(2) == 7
    assert ScoutApm.TestTracing.add_five(3) == 8

    [%{BatchCommand: %{commands: commands}}] = ScoutApm.TestCollector.messages()

    assert Enum.any?(commands, fn command ->
             map = Map.get(command, :StartSpan)
             map && Map.get(map, :operation) == "Job/ScoutApm.TestTracing.add_five(number)"
           end)
  end
end
