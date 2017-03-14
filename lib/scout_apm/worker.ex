defmodule ScoutApm.Worker do
  use GenServer
  import Logger

  # 60 seconds
  @tick_interval 60_000

  ## Client API

  def start_link do
    GenServer.start_link(__MODULE__, :ok, [name: ScoutApm.Worker])
  end

  def register_layer(type, name, time) do
    case Process.whereis(ScoutApm.Worker) do
      nil -> Logger.info("Couldn't find worker?")
      pid ->
        Logger.info("Found a pid")
        GenServer.cast(pid, {:register_layer, type, name, time})
    end
  end

  ## Server Callbacks

  def init(:ok) do
    start_timer()
    {:ok, initial_state()}
  end

  def handle_call({_}, _from, _state) do
    {:reply, nil}
  end

  def handle_cast({:register_layer, type, name, time}, state) do
    new_state = %{state |
      metric_set: ScoutApm.MetricSet.absorb(state[:metric_set], type, name, time)
    }
    {:noreply, new_state}
  end

  def handle_info(:tick, state) do
    state[:metric_set]
    |> ScoutApm.Payload.new
    |> ScoutApm.Payload.encode
    |> ScoutApm.Reporter.post

    {:noreply, initial_state()}
  end

  def initial_state do
    %{
      metric_set: ScoutApm.MetricSet.new()
    }
  end

  # Set up a timer that runs `handle_info(:tick, state)` on self every X milliseconds.
  def start_timer do
    :timer.send_interval(@tick_interval, :tick)
  end
end

