defmodule ScoutApm.Watcher do
  @moduledoc """
  A simple module to log when a watched process fails. Only works to watch
  module based workers currently, not arbitrary pids. See usage in application.ex
  """

  use GenServer

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
    ScoutApm.Logger.info("Setup ScoutApm.Watcher on #{inspect mod}")
    {:ok, :ok}
  end

  # If the logger itself is the one that died on us, we probably will
  # not log that. Also, I'm not sure of the order of events. Say that
  # `Store` crashes, both the supervisor and this watcher get notified,
  # but the supervisor will shut down and restart this process as well.
  def handle_info({:DOWN, _, _, {what, _node}, reason}, state) do
    ScoutApm.Logger.info("ScoutAPM Watcher: #{inspect what} Stopped: #{inspect reason}")
    {:stop, :normal, state}
  end
end
