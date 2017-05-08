defmodule ScoutApm.Payload do
  alias ScoutApm.MetricSet
  alias ScoutApm.Internal.Metric

  defstruct metadata: %{},
            metrics: [],
            slow_transactions: [],
            jobs: [],
            slow_jobs: [],
            histograms: []


  def new(timestamp, metric_set, traces, histograms) do
    %ScoutApm.Payload{
      metadata: ScoutApm.Payload.Metadata.new(timestamp),
      metrics: metrics(metric_set),
      slow_transactions: make_traces(traces),
      histograms: make_histograms(histograms),
    }
  end

  def metrics(%MetricSet{} = metric_set) do
    metric_set
    |> ScoutApm.MetricSet.to_list
    |> Enum.map(fn metric -> make_metric(metric) end)
  end

  def make_metric(%Metric{} = metric) do
    ScoutApm.Payload.Metric.new(metric)
  end

  def make_traces(traces) do
    traces
      |> Enum.map(fn trace -> make_trace(trace) end)
  end

  def make_trace(trace) do
    ScoutApm.Payload.SlowTransaction.new(trace)
  end

  def make_histograms(%{} = histograms) do
    Enum.map(histograms,
             fn {key, histo} ->
               %{
                 name: key,
                 histogram: histo
                            |> ApproximateHistogram.to_list
                            |> Enum.map(fn {val, count} -> [val, count] end),
               }
             end)
  end

  def total_call_count(%__MODULE__{} = payload) do
    Enum.reduce(payload.metrics, 0, fn(met, acc) ->
      case met.key.bucket do
        "Controller" -> 
          met.call_count + acc
        _ -> acc
      end
    end)
  end

  def encode(payload) do
    Poison.encode!(payload)
  end
end

