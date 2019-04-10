defmodule ScoutApm.TracingTest do
  use ExUnit.Case

  setup do
    ScoutApm.TestCollector.clear_messages()
    :ok
  end

  describe "transaction block" do
    test "usage with import" do
      ScoutApm.TestTracing.transaction_block(1)
    end
  end

  describe "deftransaction" do
    test "creates histograms with sensible defaults" do
      assert ScoutApm.TestTracing.add_one(1) == 2
      assert ScoutApm.TestTracing.add_one(1.0) == 2.0

      [%{BatchCommand: %{commands: commands1}}, %{BatchCommand: %{commands: commands2}}] = ScoutApm.TestCollector.messages()

      assert Enum.any?(commands1, fn(command) ->
        map = Map.get(command, :StartSpan)
        map && Map.get(map, :operation) == "Job/ScoutApm.TestTracing.add_one(integer) when is_integer(integer)"
      end)

      assert Enum.any?(commands2, fn(command) ->
        map = Map.get(command, :StartSpan)
        map && Map.get(map, :operation) == "Job/ScoutApm.TestTracing.add_one(number) when is_float(number)"
      end)
    end

    test "creates histograms with overridden type and name" do
      assert ScoutApm.TestTracing.add_two(1) == 3
      assert ScoutApm.TestTracing.add_two(1.0) == 3.0

      [%{BatchCommand: %{commands: commands1}}, %{BatchCommand: %{commands: commands2}}] = ScoutApm.TestCollector.messages()

      assert Enum.any?(commands1, fn(command) ->
        map = Map.get(command, :StartSpan)
        map && Map.get(map, :operation) == "Controller/test1"
      end)

      assert Enum.any?(commands2, fn(command) ->
        map = Map.get(command, :StartSpan)
        map && Map.get(map, :operation) == "Job/test2"
      end)
    end
  end

  describe "deftiming" do
    test "creates histograms with sensible defaults" do
      assert ScoutApm.TestTracing.add_three(1) == 4
      assert ScoutApm.TestTracing.add_three(1.0) == 4

      [%{BatchCommand: %{commands: commands1}}, %{BatchCommand: %{commands: commands2}}] = ScoutApm.TestCollector.messages()

      assert Enum.any?(commands1, fn(command) ->
        map = Map.get(command, :StartSpan)
        map && Map.get(map, :operation) == "Custom/ScoutApm.TestTracing.add_three(integer) when is_integer(integer)"
      end)

      assert Enum.any?(commands2, fn(command) ->
        map = Map.get(command, :StartSpan)
        map && Map.get(map, :operation) == "Custom/ScoutApm.TestTracing.add_three(number) when is_float(number)"
      end)
    end

    test "creates histograms with overridden type and name" do
      assert ScoutApm.TestTracing.add_four(1) == 5
      assert ScoutApm.TestTracing.add_four(1.0) == 5.0

      [%{BatchCommand: %{commands: commands1}}, %{BatchCommand: %{commands: commands2}}] = ScoutApm.TestCollector.messages()

      assert Enum.any?(commands1, fn(command) ->
        map = Map.get(command, :StartSpan)
        map && Map.get(map, :operation) == "Adding/add integers"
      end)

      assert Enum.any?(commands2, fn(command) ->
        map = Map.get(command, :StartSpan)
        map && Map.get(map, :operation) == "Controller/add floats"
      end)
    end
  end

  test "marks as error" do
    assert ScoutApm.TestTracing.add_one_with_error(2) == 3
    assert ScoutApm.TestTracing.add_one_with_error(2) == 3

    [%{BatchCommand: %{commands: commands1}}, %{BatchCommand: %{commands: commands2}}] = ScoutApm.TestCollector.messages()

    assert Enum.any?(commands1, fn(command) ->
      map = Map.get(command, :TagSpan)
      map && Map.get(map, :tag) == "error" && Map.get(map, :value) == "true"
    end)

    assert Enum.any?(commands2, fn(command) ->
      map = Map.get(command, :TagSpan)
      map && Map.get(map, :tag) == "error" && Map.get(map, :value) == "true"
    end)
  end

  test "marks as ignored" do
    Code.eval_string(
      """
      defmodule TracingAnnotationTestModule do
        import ScoutApm.Tracing

        deftransaction add_three(number) do
          if number > 2 do
            ScoutApm.TrackedRequest.ignore()
          end
          number + 3
        end
      end
      """)
    assert TracingAnnotationTestModule.add_three(2) == 5
    assert TracingAnnotationTestModule.add_three(3) == 6
    [%{BatchCommand: %{commands: commands}}] = ScoutApm.TestCollector.messages()
    assert Enum.any?(commands, fn(command) ->
      map = Map.get(command, :StartSpan)
      map && Map.get(map, :operation) == "Job/TracingAnnotationTestModule.add_three(number)"
    end)
  end
end
