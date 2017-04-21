defmodule ScoutApm.Store do
  use GenServer
  require Logger

  alias ScoutApm.Internal.Metric
  alias ScoutApm.Internal.Trace
  alias ScoutApm.StoreReportingPeriod

  # 60 seconds
  # @tick_interval 60_000
  @tick_interval 10_000

  ## Client API

  def start_link do
    GenServer.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

  def record_metric(%Metric{} = metric) do
    case Process.whereis(__MODULE__) do
      nil -> Logger.info("Couldn't find ScoutAPM Store Process. :scout_apm application is likely not started.")
      pid ->
        GenServer.cast(pid, {:record_metric, metric})
    end
  end

  def record_trace(%Trace{} = trace) do
    case Process.whereis(__MODULE__) do
      nil -> Logger.info("Couldn't find ScoutAPM Store Process. :scout_apm application is likely not started.")
      pid ->
        GenServer.cast(pid, {:record_trace, trace})
    end
  end

  def record_per_minute_histogram(key, duration) do
    case Process.whereis(__MODULE__) do
      nil -> Logger.info("Couldn't find worker!?")
      pid ->
        GenServer.cast(pid, {:record_per_minute_histogram, key, duration})
    end
  end

  ## Server Callbacks

  def init(:ok) do
    initial_state = %{
      reporting_periods: []
    }

    schedule_tick()

    {:ok, initial_state}
  end

  def handle_call({_}, _from, _state) do
    {:noreply, nil}
  end

  def handle_cast({:record_metric, %Metric{} = metric}, state) do
    { rp, new_state } = find_or_create_reporting_period(state)
    StoreReportingPeriod.record_metric(rp, metric)

    {:noreply, new_state}
  end

  # TODO: Lazy-generate trace (ie, this should take a thunk that evaluates into a trace)
  # TODO: Score the thunk, so we can determine if the set wants to even bother resolving the trace
  # TODO: Callback for "time since last-seen" score
  def handle_cast({:record_trace, %Trace{} = trace}, state) do
    {rp, new_state} = find_or_create_reporting_period(state)
    StoreReportingPeriod.record_trace(rp, trace)
    {:noreply, new_state}
  end

  def handle_cast({:record_per_minute_histogram, key, duration}, state) do
    {rp, new_state} = find_or_create_reporting_period(state)
    StoreReportingPeriod.record_timing(rp, key, duration)
    {:noreply, new_state}
  end

  # Split reporting periods we have into ready & not ready. Ship the ready ones
  # (which stops their process), and next_state has the ones that weren't ready.
  def handle_info(:tick, state) do
    # Ensure a current reporting period is initialized. Otherwise, samplers won't run unless there is web throughput.
    {_, new_state} = find_or_create_reporting_period(state)

    Enum.each(categorized_reporting_periods(new_state, :ready), fn rp ->
      Task.start(fn ->
        rp |> capture_samplers |> StoreReportingPeriod.report!
      end)
    end)

    schedule_tick()

    {:noreply, %{new_state | reporting_periods: categorized_reporting_periods(new_state, :not_ready)}}
  end

  # Returns a List of reporting periods of +type+ (expected to be :ready or :not_ready).
  defp categorized_reporting_periods(state, type) do
    Enum.group_by(state.reporting_periods,
      fn rp -> StoreReportingPeriod.ready_to_report?(rp) end)[type] |> List.wrap
  end

  # Runs samplers, which should run once per-minute just before reporting.
  defp capture_samplers(reporting_period) do
    Logger.debug("Capturing samplers")
    Enum.each([ScoutApm.Instruments.Samplers.Memory], fn sampler ->
      sampler.metrics |> Enum.each(fn metric ->
        StoreReportingPeriod.record_metric(reporting_period, metric)
      end)
    end)
    reporting_period
  end

  # Finds an existing reporting period record, or creates one, and adds it to
  # state. Either way, the return value is a two tuple:
  # { reporting period, (maybe updated) state }
  defp find_or_create_reporting_period(state, time \\ nil) do
    now = if time do
      time
    else
      NaiveDateTime.utc_now()
    end

    case Enum.find(state.reporting_periods, fn rp -> StoreReportingPeriod.covers?(rp, now) end) do
      nil ->
        {:ok, rp} = StoreReportingPeriod.start_link(now)
        {rp, %{state | reporting_periods: [rp | state.reporting_periods]}}
      rp ->
        {rp, state}
    end
  end

  defp schedule_tick() do
    Process.send_after(self(), :tick, @tick_interval)
  end
end
