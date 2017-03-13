defmodule ScoutApm.Worker do
  use GenServer
  import Logger

  ## Client API

  def start_link do
    GenServer.start_link(__MODULE__, :ok, [name: ScoutApm.Worker])
  end

  ## Server Callbacks

  def init(:ok) do
    {:ok, %{}}
  end

  def handle_call({_}, _from, state) do
    {:reply, nil}
  end

  def handle_cast({:time, t}, state) do
    Logger.info("Worker got a report of time: #{t}")
    new_state = Map.update(state, :total_time, 0, fn current_val -> current_val + t end)
    Logger.info("total time so far is: #{new_state[:total_time]}")
    {:noreply, new_state}
  end
end

