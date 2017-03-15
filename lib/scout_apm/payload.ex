defmodule ScoutApm.Payload do
  import Logger, only: [info: 1]

  defstruct metadata: %{},
            metrics: %{},
            slow_transactions: %{},
            jobs: %{},
            slow_jobs: %{},
            histograms: %{}

  def new(metric_set) do
    %ScoutApm.Payload{
      metadata: ScoutApm.Payload.Metadata.new(),
      metrics: metrics(metric_set)
    }
  end

  def metrics(metric_set) do
    metric_set
    |> ScoutApm.MetricSet.to_list
    |> Enum.map(fn metric -> make_metric(metric) end)
  end

  def make_metric(metric) do
    scope_map =
      case metric.scope do
        %{:type => type, :name => name} -> %{bucket: type, name: name}
        _ -> %{}
      end

    %{
      key: %{
        bucket: metric[:type],
        name: metric[:name],
        desc: nil,
        extra: nil,
        scope: scope_map,
      },
      call_count: metric[:call_count],
      min_call_time: metric[:min_call_time],
      max_call_time: metric[:max_call_time],
      total_call_time: metric[:total_call_time],
      total_exclusive_time: metric[:total_exclusive_time],
      sum_of_squares: 0,
    }
  end

  def encode(payload) do
    Poison.encode!(payload)
  end

  ## Just a handy thing to not lose
  def application_details do
    Application.spec(:my_app, :vsn)
  end
end

