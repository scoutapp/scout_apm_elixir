defmodule ScoutApm.Watcher do  
  use GenServer
  require Logger

  @server __MODULE__

  def start_link(mod) do
    GenServer.start_link(@server, mod)
  end

  def init(mod) do
    Process.monitor(mod)
    Logger.info("Setup ScoutApm.Watcher on #{inspect mod}")
    {:ok, :ok}
  end

  def handle_info({:DOWN, _, _, {what, _node}, reason}, _from) do
    Logger.info("CRASH CRASH: #{inspect what} CRASHED: #{inspect reason}")
    {:noreply, :ok}
  end
end
