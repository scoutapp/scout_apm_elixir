defmodule ScoutApm.Payload.JobRecordTest do
  use ExUnit.Case, async: true

  alias ScoutApm.Internal.JobRecord
  alias ScoutApm.Payload.Jobs
  alias ScoutApm.MetricSet

  describe "new/1" do
    test "with an empty list" do
      assert [] == Jobs.new([])
    end

    test "from a single JobRecord" do
      jr = %JobRecord{
        queue: "q",
        name: "name",
        count: 1,
        errors: 0,
        total_time: ApproximateHistogram.new() |> ApproximateHistogram.add(1),
        exclusive_time: ApproximateHistogram.new() |> ApproximateHistogram.add(1),
        metrics: MetricSet.new()
      }

      assert [
               %{
                 name: "name",
                 queue: "q",
                 count: 1,
                 errors: 0,
                 exclusive_time: [[1.0, 1]],
                 total_time: [[1.0, 1]],
                 metrics: []
               }
             ] == Jobs.new([jr])
    end
  end
end
