defmodule ScoutApm.Payload.Jobs do
  @moduledoc """
  """

  alias ScoutApm.MetricSet
  alias ScoutApm.Internal.JobRecord
  alias ScoutApm.Internal.Duration

  @spec new(list(JobRecord.t)) :: list(map)
  def new(jobs) do
    jobs
    |> Enum.map(&make_job/1)
  end

  defp make_job(job) do
    %{
      queue: job.queue,
      name: job.name,
      count: job.count,
      errors: job.errors,

      total_time: job.total_time |> ApproximateHistogram.to_list() |> to_jsonable_histo,
      exclusive_time: job.exclusive_time |> ApproximateHistogram.to_list() |> to_jsonable_histo,

      metrics: ScoutApm.Payload.NewMetrics.new(job.metrics),
    }
  end

  # A little mapping to turn histo's 2 tuples into 2 elem lists
  defp to_jsonable_histo(histo), do: Enum.map(histo, &Tuple.to_list/1)
end
