defmodule ScoutApm.Config do
  @moduledoc """
  Public interface to configuration settings. Reads from several configuration
  sources, giving each an opportunity to respond with its value before trying
  the next.

  Application.get_env, and Defaults are the the current ones, with
  an always-nil at the end of the chain.
  """

  use GenServer

  require Logger

  alias ScoutApm.Config.Coercions

  @name __MODULE__

  ## Client API

  def start_link do
    GenServer.start_link(@name, :ok, [name: @name])
  end

  def find(key) do
    GenServer.call(@name, {:find, key})
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
    val = Enum.reduce_while(state, nil, fn {mod, data}, _acc ->
      if mod.contains?(data, key) do
        raw = mod.lookup(data, key)
        case coercion(key).(raw) do
          {:ok, c} ->
            {:halt, c}
          :error ->
            Logger.info("Coercion of configuration #{key} failed. Ignoring")
            {:cont, nil}
        end
      else
        {:cont, nil}
      end
    end)

    {:reply, val, state}
  end

  def handle_cast({}, state) do
    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp coercion(:monitor), do: &Coercions.boolean/1
  defp coercion(_), do: fn x -> {:ok, x} end
end

