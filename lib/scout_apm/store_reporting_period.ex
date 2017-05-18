defmodule ScoutApm.StoreReportingPeriod do
  require Logger

  alias ScoutApm.Internal.Duration
  alias ScoutApm.Internal.WebTrace
  alias ScoutApm.Internal.JobRecord
  alias ScoutApm.Internal.JobTrace
  alias ScoutApm.MetricSet
  alias ScoutApm.ScoredItemSet

  def start_link(timestamp) do
    Agent.start_link(fn ->
      %{
        time: beginning_of_minute(timestamp),
        web_metric_set: MetricSet.new(),
        web_traces: ScoredItemSet.new(),

        # key is JobRecord.key(), value is a single Merged JobRecord
        jobs: %{},
        job_traces: ScoredItemSet.new(),

        # a map of key => ApproximateHistogram
        histograms: %{},
      }
    end)
  end

  def record_web_trace(pid, trace) do
    Agent.update(pid,
      fn state ->
        %{state | web_traces: ScoredItemSet.absorb(state.web_traces, WebTrace.as_scored_item(trace))}
      end
    )
  end

  # This just passes through to web_metric, but leave it as a function
  # so we can reroute it later.
  def record_sampler_metric(pid, metric), do: record_web_metric(pid, metric)

  def record_web_metric(pid, metric) do
    Agent.update(pid,
      fn state ->
        %{state | web_metric_set: MetricSet.absorb(state.web_metric_set, metric)}
      end
    )
  end

  def record_job_record(pid, job_record) do
    Agent.update(pid,
      fn state ->
        %{state |
            jobs: Map.update(
              state.jobs,
              JobRecord.key(job_record),
              job_record,
              fn existing -> JobRecord.merge(job_record, existing) end
            )
         }
      end
    )
  end

  def record_job_trace(pid, trace) do
    Agent.update(pid,
      fn state ->
        %{state | job_traces: ScoredItemSet.absorb(state.job_traces, JobTrace.as_scored_item(trace))}
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

  # Returns true if the timestamp is part of the minute of this StoreReportingPeriod
  def covers?(pid, timestamp) do
    t = Agent.get(pid, fn state -> state.time end)

    NaiveDateTime.compare(t, beginning_of_minute(timestamp)) == :eq
  end

  # How many seconds from the "beginning of minute" time until we say that its
  # ok to report this reporting period?
  @reporting_age 60

  # Returns :ready | :not_ready depending on if this reporting periods time is now past
  def ready_to_report?(pid) do
    t = Agent.get(pid, fn state -> state.time end)
    now = NaiveDateTime.utc_now()

    diff = NaiveDateTime.diff(now, t, :seconds)

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
    try do
      state = Agent.get(pid, fn state -> state end)
      Agent.stop(pid)

      payload = ScoutApm.Payload.new(
        state.time,

        state.web_metric_set,
        ScoredItemSet.to_list(state.web_traces, :without_scores),

        state.histograms,

        Map.values(state.jobs),
        ScoredItemSet.to_list(state.job_traces, :without_scores)
      )

      Logger.debug("Reporting: Payload created with data from #{ScoutApm.Payload.total_call_count(payload)} requests.")
      Logger.debug("Payload #{inspect payload}")

      encoded = ScoutApm.Payload.encode(payload)

      Logger.debug("Encoded Payload: #{inspect encoded}")

      ScoutApm.Reporter.report(encoded)
    rescue
      e in RuntimeError -> Logger.info("Reporting runtime error: #{inspect e}")
      e -> Logger.info("Reporting other error: #{inspect e}")
    end
  end

  defp beginning_of_minute(datetime) do
    {date, {hour, minute, _}} = NaiveDateTime.to_erl(datetime)
    {:ok, beginning} = NaiveDateTime.from_erl({date, {hour, minute, 0}})
    beginning
  end
end
