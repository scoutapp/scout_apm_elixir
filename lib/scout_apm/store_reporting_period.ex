defmodule ScoutApm.StoreReportingPeriod do

  alias ScoutApm.Internal.Duration
  alias ScoutApm.Internal.Trace
  alias ScoutApm.MetricSet
  alias ScoutApm.ScoredItemSet

  def start_link(timestamp) do
    Agent.start_link(fn ->
      %{
        time: beginning_of_minute(timestamp),
        metric_set: MetricSet.new(),
        traces: ScoredItemSet.new(),
        histograms: %{}, # a map of key => ApproximateHistogram
      }
    end)
  end

  def record_trace(pid, trace) do
    Agent.update(pid,
      fn state ->
        %{state | traces: ScoredItemSet.absorb(state.traces, Trace.as_scored_item(trace))}
      end
    )
  end

  def record_metric(pid, metric) do
    Agent.update(pid,
      fn state ->
        %{state | metric_set: MetricSet.absorb(state.metric_set, metric)}
      end
    )
  end

  def record_timing(pid, key, %Duration{} = timing), do: record_timing(pid, key, Duration.as(timing, :seconds))
  def record_timing(pid, key, timing) do
    Agent.update(pid,
      fn state ->
        %{state | histograms:
          Map.update(state.histograms, key, ApproximateHistogram.new(), fn histo ->
            ApproximateHistogram.add(histo, timing)
          end)}
      end
    )
  end

  def time(pid) do
    t = Agent.get(pid, fn state -> state.time end)
    {:ok, str} = Timex.format(t, "{ISO:Extended}")
    str
  end

  # Returns true if the timestamp is part of the minute of this StoreReportingPeriod
  def covers?(pid, timestamp) do
    t = Agent.get(pid, fn state -> state.time end)

    Timex.compare(t, beginning_of_minute(timestamp)) == 0
  end

  # How many seconds from the "beginning of minute" time until we say that its
  # ok to report this reporting period?
  @reporting_age 60

  # Returns :ready | :not_ready depending on if this reporting periods time is now past
  def ready_to_report?(pid) do
    t = Agent.get(pid, fn state -> state.time end)
    now = Timex.now()

    diff = Timex.diff(now, t, :seconds)

    if diff > @reporting_age do
      :ready
    else
      :not_ready
    end
  end

  # Pushes all data from the agent outward to the reporter.
  # Then stops the underlying process holding that info.  This must be the last
  # call to this ReportingPeriod, it is a stopped process after this.
  def report!(pid) do
    state = Agent.get(pid, fn state -> state end)

    Agent.stop(pid)

    ScoutApm.Payload.new(state.time,
                         state.metric_set,
                         ScoredItemSet.to_list(state.traces, :without_scores),
                         state.histograms
                       )
    |> ScoutApm.Payload.encode
    |> ScoutApm.Reporter.post
  end

  defp beginning_of_minute(datetime) do
    datetime
    |> Timex.set(second: 0)
    |> Timex.set(microsecond: {0, 0})
  end
end
