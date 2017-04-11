defmodule ScoutApm.Config do
  @moduledoc """
  Public interface to configuration settings. Reads from several configuration
  sources, giving each an opportunity to respond with its value before trying
  the next.

  Application.get_env, and Defaults are the the current ones, with
  an always-nil at the end of the chain.
  """

  use GenServer

  ## Client API

  def start_link do
    GenServer.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

  def find(key) do
    pid = Process.whereis(__MODULE__)
    GenServer.call(pid, {:find, key})
  end

  ## Server Callbacks

  def init(:ok) do
    initial_state = [
      {ScoutApm.Config.Application, ScoutApm.Config.Application.load()},
      {ScoutApm.Config.Defaults, ScoutApm.Config.Defaults.load()},
      {ScoutApm.Config.Null, ScoutApm.Config.Null.load()},
    ]

    {:ok, initial_state}
  end

  def handle_call({:find, key}, _from, state) do
    # Which config source wants to answer this?
    {mod, data} = Enum.find(state, fn {mod, data} -> mod.contains?(data, key) end)

    val = mod.lookup(data, key)

    {:reply, val, state}
  end

  def handle_cast({}, state) do
    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end
end

