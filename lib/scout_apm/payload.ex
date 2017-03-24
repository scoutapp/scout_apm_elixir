defmodule ScoutApm.Payload do
  require Logger

  alias ScoutApm.MetricSet
  alias ScoutApm.Internal.Metric

  defstruct metadata: %{},
            metrics: %{},
            slow_transactions: [],
            jobs: %{},
            slow_jobs: %{},
            histograms: %{}

  def new(metric_set, traces) do
    %ScoutApm.Payload{
      metadata: ScoutApm.Payload.Metadata.new(),
      metrics: metrics(metric_set),
      slow_transactions: make_traces(traces)
    }
  end

  def metrics(%MetricSet{}=metric_set) do
    metric_set
    |> ScoutApm.MetricSet.to_list
    |> Enum.map(fn metric -> make_metric(metric) end)
  end

  def make_metric(%Metric{}=metric) do
    ScoutApm.Payload.Metric.new(metric)
  end

  def make_traces(traces) do
    traces
      |> Enum.map(fn trace -> make_trace(trace) end)
  end

  def make_trace(trace) do
    ScoutApm.Payload.SlowTransaction.new(trace)
  end

  def encode(payload) do
    Poison.encode!(payload)
  end

  ## Just a handy thing to not lose
  def application_details do
    Application.spec(:my_app, :vsn)
  end
end

