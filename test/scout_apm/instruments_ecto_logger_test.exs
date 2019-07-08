defmodule ScoutApm.Instruments.EctoLoggerTest do
  use ExUnit.Case, async: false

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

      assert %{
               children: [
                 [
                   %{
                     name: "SQL#users",
                     type: "Ecto"
                   }
                 ]
               ]
             } = Process.get(:scout_apm_request)
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

      assert %{
               children: [
                 [
                   %{
                     name: "select#users",
                     type: "Ecto"
                   }
                 ]
               ]
             } = Process.get(:scout_apm_request)
    end
  end
end
