defmodule ScoutApm.Instruments.Samplers.Memory do
  def metrics do
    [
      ScoutApm.Internal.Metric.from_sampler_value("Memory", "Physical", total_mb())
    ]
  end

  def total_bytes do
    :erlang.memory(:total)
  end

  def total_mb do
    total_bytes() / 1024.0 / 1024.0
  end
end
