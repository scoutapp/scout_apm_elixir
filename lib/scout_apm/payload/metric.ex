defmodule ScoutApm.Payload.Metric do
  alias ScoutApm.Internal.Duration

  def new(%ScoutApm.Internal.Metric{} = metric) do
    %{
      key: %{
        bucket: metric.type,
        name: metric.name,
        desc: metric.desc,
        extra: nil,
        scope: case metric.scope do
          %{:type => type, :name => name} ->
            %{
              bucket: type,
              name: name
            }
          _ -> %{}
        end
      },

      call_count: metric.call_count,
      total_call_time: Duration.as(metric.total_time, :seconds),
      total_exclusive_time:  Duration.as(metric.total_time, :seconds),
      min_call_time: Duration.as(metric.min_time, :seconds),
      max_call_time: Duration.as(metric.max_time, :seconds),

      sum_of_squares: 0, # Unused, but still part of payload
    }
  end
end
