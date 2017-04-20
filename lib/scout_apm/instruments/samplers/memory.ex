defmodule ScoutApm.Instruments.Samplers.Memory do
  def metrics do
    value = as_duration()
    [
      %ScoutApm.Internal.Metric{
        type: "Memory",
        name: "Physical",
        call_count: 1,
        total_time: value,
        exclusive_time: value,
        min_time: value,
        max_time: value,
      }
    ]
  end

  # Hacky right now...we are really only handling timing metrics. This basically sends up the value in MB
  # exactly as collected with no units conversion. Server-side, we expect memory to be in MB.
  def as_duration do
    ScoutApm.Internal.Duration.new(total_mb(), :seconds)
  end

  def total_bytes do
    :erlang.memory(:total)
  end

  def total_mb do
    total_bytes() / 1024.0 / 1024.0
  end
end
