defmodule ScoutApm.Instruments.EctoLoggerTest do
  use ExUnit.Case

  setup do
    ScoutApm.TestCollector.clear_messages()
    :ok
  end

  describe "record/2" do
    test "successfully records query" do
      value = %{
        decode_time: 16000,
        query_time: 1_192_999,
        queue_time: 36000
      }

      metadata = %{
        source: "users",
        query: "SELECT u0.\"id\", u0.\"name\", u0.\"age\" FROM \"users\" AS u0"
      }

      ScoutApm.TrackedRequest.start_layer("Controller", "test")
      ScoutApm.Instruments.EctoLogger.record(value, metadata)
      ScoutApm.TrackedRequest.stop_layer()

      [%{BatchCommand: %{commands: commands}}] = ScoutApm.TestCollector.messages()

      assert Enum.any?(commands, fn command ->
               span = Map.get(command, :StartSpan)

               span &&
                 Map.get(span, :operation) ==
                   "SQL/Query"
             end)

      assert Enum.any?(commands, fn command ->
               tag = Map.get(command, :TagSpan)

               tag &&
                 Map.get(tag, :tag) == "db.statement"
             end)
    end

    test "includes db.rows_returned and db.operation tags when result is available" do
      value = %{
        decode_time: 16000,
        query_time: 1_192_999,
        queue_time: 36000
      }

      metadata = %{
        source: "users",
        query: "SELECT u0.\"id\", u0.\"name\", u0.\"age\" FROM \"users\" AS u0",
        result: {:ok, %{command: :select, num_rows: 5}}
      }

      ScoutApm.TrackedRequest.start_layer("Controller", "test")
      ScoutApm.Instruments.EctoLogger.record(value, metadata)
      ScoutApm.TrackedRequest.stop_layer()

      [%{BatchCommand: %{commands: commands}}] = ScoutApm.TestCollector.messages()

      assert Enum.any?(commands, fn command ->
               tag = Map.get(command, :TagSpan)
               tag && Map.get(tag, :tag) == "db.rows_returned" && Map.get(tag, :value) == "5"
             end)

      assert Enum.any?(commands, fn command ->
               tag = Map.get(command, :TagSpan)
               tag && Map.get(tag, :tag) == "db.operation" && Map.get(tag, :value) == "Select"
             end)
    end
  end

  describe "log/1" do
    test "successfully records query" do
      entry = %{
        decode_time: 16000,
        query_time: 1_192_999,
        queue_time: 36000,
        result: {:ok, %{__struct__: Postgrex.Result, command: :select}},
        source: "users",
        query: "SELECT u0.\"id\", u0.\"name\", u0.\"age\" FROM \"users\" AS u0"
      }

      ScoutApm.TrackedRequest.start_layer("Controller", "test")
      ScoutApm.Instruments.EctoLogger.log(entry)
      ScoutApm.TrackedRequest.stop_layer()

      [%{BatchCommand: %{commands: commands}}] = ScoutApm.TestCollector.messages()

      assert Enum.any?(commands, fn command ->
               span = Map.get(command, :StartSpan)

               span &&
                 Map.get(span, :operation) ==
                   "SQL/Query"
             end)

      assert Enum.any?(commands, fn command ->
               tag = Map.get(command, :TagSpan)

               tag &&
                 Map.get(tag, :tag) == "db.statement"
             end)
    end

    test "includes db.rows_returned and db.operation tags" do
      entry = %{
        decode_time: 16000,
        query_time: 1_192_999,
        queue_time: 36000,
        result: {:ok, %{command: :insert, num_rows: 1}},
        source: "users",
        query: "INSERT INTO \"users\" (\"name\") VALUES ($1)"
      }

      ScoutApm.TrackedRequest.start_layer("Controller", "test")
      ScoutApm.Instruments.EctoLogger.log(entry)
      ScoutApm.TrackedRequest.stop_layer()

      [%{BatchCommand: %{commands: commands}}] = ScoutApm.TestCollector.messages()

      assert Enum.any?(commands, fn command ->
               tag = Map.get(command, :TagSpan)
               tag && Map.get(tag, :tag) == "db.rows_returned" && Map.get(tag, :value) == "1"
             end)

      assert Enum.any?(commands, fn command ->
               tag = Map.get(command, :TagSpan)
               tag && Map.get(tag, :tag) == "db.operation" && Map.get(tag, :value) == "Insert"
             end)
    end
  end

  describe "extract_result_info/1" do
    alias ScoutApm.Instruments.EctoLogger

    test "extracts command and num_rows from successful result" do
      metadata = %{result: {:ok, %{command: :select, num_rows: 10}}}
      assert {"Select", 10} = EctoLogger.extract_result_info(metadata)
    end

    test "normalizes insert command" do
      metadata = %{result: {:ok, %{command: :insert, num_rows: 1}}}
      assert {"Insert", 1} = EctoLogger.extract_result_info(metadata)
    end

    test "normalizes update command" do
      metadata = %{result: {:ok, %{command: :update, num_rows: 3}}}
      assert {"Update", 3} = EctoLogger.extract_result_info(metadata)
    end

    test "normalizes delete command" do
      metadata = %{result: {:ok, %{command: :delete, num_rows: 2}}}
      assert {"Delete", 2} = EctoLogger.extract_result_info(metadata)
    end

    test "handles unknown commands by capitalizing" do
      metadata = %{result: {:ok, %{command: :truncate, num_rows: 0}}}
      assert {"Truncate", 0} = EctoLogger.extract_result_info(metadata)
    end

    test "returns nil tuple when result is error" do
      metadata = %{result: {:error, :some_error}}
      assert {nil, nil} = EctoLogger.extract_result_info(metadata)
    end

    test "returns nil tuple when result is not present" do
      metadata = %{source: "users"}
      assert {nil, nil} = EctoLogger.extract_result_info(metadata)
    end

    test "handles result without num_rows" do
      metadata = %{result: {:ok, %{command: :select}}}
      assert {"Select", nil} = EctoLogger.extract_result_info(metadata)
    end

    test "handles result without command" do
      metadata = %{result: {:ok, %{num_rows: 5}}}
      assert {nil, 5} = EctoLogger.extract_result_info(metadata)
    end
  end
end
