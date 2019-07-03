defmodule ScoutApm.Payload do
  alias ScoutApm.MetricSet
  alias ScoutApm.Internal.{DbMetric, Metric}

  defstruct metadata: %{},
            metrics: [],
            slow_transactions: [],
            jobs: [],
            slow_jobs: [],
            histograms: [],
            db_metrics: []

  def new(timestamp, web_metric_set, web_traces, histograms, jobs, job_traces, db_metric_map) do
    %ScoutApm.Payload{
      metadata: ScoutApm.Payload.Metadata.new(timestamp),
      metrics: metrics(web_metric_set),
      slow_transactions: make_traces(web_traces),
      histograms: make_histograms(histograms),
      jobs: ScoutApm.Payload.Jobs.new(jobs),
      slow_jobs: ScoutApm.Payload.SlowJobs.new(job_traces),
      db_metrics: %{
        query: make_db_metrics(db_metric_map)
      }
    }
  end

  def metrics(%MetricSet{} = web_metric_set) do
    web_metric_set
    |> ScoutApm.MetricSet.to_list()
    |> Enum.map(fn metric -> make_metric(metric) end)
  end

  def make_metric(%Metric{} = metric) do
    ScoutApm.Payload.Metric.new(metric)
  end

  def make_traces(web_traces) do
    web_traces
    |> Enum.map(fn trace -> make_trace(trace) end)
  end

  def make_trace(web_trace) do
    ScoutApm.Payload.SlowTransaction.new(web_trace)
  end

  def make_db_metrics(db_metric_map) do
    Map.values(db_metric_map)
    |> Enum.map(fn %DbMetric{} = db_metric ->
      %{
        model_name: db_metric.model_name,
        operation: db_metric.operation,
        scope: db_metric.scope,
        transaction_count: db_metric.transaction_count,
        call_time: db_metric.call_time,
        min_call_time: db_metric.min_call_time,
        max_call_time: db_metric.max_call_time,
        min_rows_returned: db_metric.min_rows_returned,
        max_rows_returned: db_metric.max_rows_returned,
        call_count: db_metric.call_count,
        rows_returned: db_metric.rows_returned,
        histogram:
          ApproximateHistogram.to_list(db_metric.histogram)
          |> Enum.map(fn {val, count} -> [val, count] end)
      }
    end)
  end

  def make_histograms(%{} = histograms) do
    Enum.map(
      histograms,
      fn {key, histo} ->
        %{
          name: key,
          histogram:
            histo
            |> ApproximateHistogram.to_list()
            |> Enum.map(fn {val, count} -> [val, count] end)
        }
      end
    )
  end

  def total_call_count(%__MODULE__{} = payload) do
    Enum.reduce(payload.metrics, 0, fn met, acc ->
      case met.key.bucket do
        "Controller" ->
          met.call_count + acc

        _ ->
          acc
      end
    end)
  end

  def encode(payload) do
    Poison.encode!(payload)
  end
end
