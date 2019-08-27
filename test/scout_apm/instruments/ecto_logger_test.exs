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
  end
end
