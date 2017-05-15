defmodule ScoutApm.Payload.NewMetrics do
  @moduledoc """
  Awkward name - we have two different metric formats in the Ruby agent,
  Jobs use this one. It's more flexible, but annoying that we have 2 formats
  """

  alias ScoutApm.Internal.Duration
  alias ScoutApm.MetricSet

  @spec new(MetricSet.t) :: list(map)
  def new(%MetricSet{} = metric_set) do
    metric_set
    |> MetricSet.to_list()
    |> Enum.map(
         fn metric ->
           # TODO: Handle Job queues correctly
           # name = if metric.type == "Job" do
             # "default/#{metric.name}"
           # else
             # metric.name
           # end
           name = metric.name

           %{
             bucket: metric.type,
             name: name,
             count: metric.call_count,
             total_call_time: Duration.as(metric.total_time, :seconds),
             total_exclusive_time: Duration.as(metric.exclusive_time, :seconds),
             min_call_time: Duration.as(metric.min_time, :seconds),
             max_call_time: Duration.as(metric.max_time, :seconds),

             total_histogram: [Duration.as(metric.total_time, :seconds)/ metric.call_count, metric.call_count],
             exclusive_histogram: [Duration.as(metric.exclusive_time, :seconds) / metric.call_count, metric.call_count],

             detail: %{
               desc: metric.desc,
               # metric.extra stuff may need to go here? (backtraces?)
             },

             # Always empty list. Will be where child metrics go later.
             metrics: [],
           }
         end)
  end
end
