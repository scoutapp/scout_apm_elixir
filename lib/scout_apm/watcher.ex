defmodule ScoutApm.Watcher do  
  @moduledoc """
  A single module to log when a watched process fails. Only works on modules
  currently, not arbitrary pids. See usage in application.ex
  """

  use GenServer
  require Logger

  @server __MODULE__

  def start_link(mod) do
    name = mod
    |> Atom.to_string
    |> Kernel.<>(".Watcher")
    |> String.to_atom

    GenServer.start_link(@server, mod, name: name)
  end

  def init(mod) do
    Process.monitor(mod)
    Logger.info("Setup ScoutApm.Watcher on #{inspect mod}")
    {:ok, :ok}
  end

  def handle_info({:DOWN, _, _, {what, _node}, reason}, state) do
    Logger.info("ScoutAPM Watcher: #{inspect what} Stopped: #{inspect reason}")
    {:stop, :normal, state}
  end
end
