defmodule ScoutApm.Store do
  use GenServer
  require Logger

  alias ScoutApm.Internal.Metric
  alias ScoutApm.Internal.Trace
  alias ScoutApm.MetricSet

  # 60 seconds
  @tick_interval 60_000
  # @tick_interval 5_000

  ## Client API

  def start_link do
    GenServer.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

  def record_metric(%Metric{}=metric) do
    case Process.whereis(__MODULE__) do
      nil -> Logger.info("Couldn't find worker!?")
      pid ->
        GenServer.cast(pid, {:record_metric, metric})
    end
  end

  def record_trace(%Trace{}=trace) do
    case Process.whereis(__MODULE__) do
      nil -> Logger.info("Couldn't find worker!?")
      pid ->
        GenServer.cast(pid, {:record_trace, trace})
    end
  end

  ## Server Callbacks

  def init(:ok) do
    start_timer()
    {:ok, initial_state()}
  end

  def handle_call({_}, _from, _state) do
    {:noreply, nil}
  end

  def handle_cast({:record_metric, %Metric{}=metric}, state) do
    new_state = %{state |
      metric_set: MetricSet.absorb(state.metric_set, metric)
    }
    {:noreply, new_state}
  end

  def handle_cast({:record_trace, %Trace{}=trace}, state) do
    new_state = %{state | traces: [trace | state.traces] }
    {:noreply, new_state}
  end


  def handle_info(:tick, state) do
    ScoutApm.Payload.new(state.metric_set, state.traces)
    |> ScoutApm.Payload.encode
    |> log_payload()
    |> ScoutApm.Reporter.post

    {:noreply, initial_state()}
  end

  def initial_state do
    %{
      metric_set: MetricSet.new(),
      traces: [], # TODO: Scored Trace Set
    }
  end

  # Set up a timer that runs `handle_info(:tick, state)` on self every X milliseconds.
  def start_timer do
    :timer.send_interval(@tick_interval, :tick)
  end

  def log_payload(p) do
    Logger.info(inspect p)
    p
  end
end

