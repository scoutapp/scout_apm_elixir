defmodule ScoutApm.Logger do
  @moduledoc """
  Logger for all ScoutApm modules.

  Defaults to pass-through to the built-in Logger, but checks first if
  the agent is set to monitor: false, or set to a higher log level.

  This is a GenServer, to easily state on what log level we're at and if
  something should be sent along.

  This doesn't currently attempt any fancy log-message elimination
  macros that the core Logger does.
  """
  use GenServer

  require Logger

  @name __MODULE__

  @default_level :info

  @valid_levels [:debug, :info, :warn, :error]

  # If you request to log a message at the left level, check if the
  # logger's current level is one of the right before letting it through
  #
  # For instance, if you ScoutApm.Logger.warn("foo"), it should be
  # printed if you're at warn, info, or debug levels
  #
  # Msg Lvl       Logger Lvl
  #  |              |
  #  |              |
  #  v              v
  @debug_levels [:debug]
  @info_levels  [:debug, :info]
  @warn_levels  [:debug, :info, :warn]
  @error_levels [:debug, :info, :warn, :error]


  ################
  #  Client API  #
  ################

  def start_link(level \\ @default_level), do: GenServer.start_link(__MODULE__, level, name: @name)

  def set_level(level), do: GenServer.cast(@name, {:set_level, level})
  def set_enabled(value) when is_boolean(value), do: GenServer.cast(@name, {:set_enabled, value})
  def enable!(), do: set_enabled(true)
  def disable!(), do: set_enabled(false)

  def reconfigure_from_config(), do: GenServer.cast(@name, :reconfigure_from_config)

  def debug(msg, metadata \\ []), do: GenServer.cast(@name, {:debug, msg, metadata})
  def info(msg, metadata \\ []), do: GenServer.cast(@name, {:info, msg, metadata})
  def warn(msg, metadata \\ []), do: GenServer.cast(@name, {:warn, msg, metadata})
  def error(msg, metadata \\ []), do: GenServer.cast(@name, {:error, msg, metadata})

  def level(), do: GenServer.call(@name, :level)
  def enabled?(), do: GenServer.call(@name, :enabled)

  ################
  #  Server API  #
  ################
  def init(level) do
    state = %{level: level, enabled: true}
    {:ok, state}
  end

  def handle_call(:level, _from, %{level: level} = state), do: {:reply, level, state}
  def handle_call(:enabled, _from, %{enabled: enabled} = state), do: {:reply, enabled, state}

  def handle_cast(:reconfigure_from_config, state) do
    level = ScoutApm.Config.find(:log_level) || @default_level
    enabled = ScoutApm.Config.find(:monitor)

    {
      :noreply,
      %{state |
        level: level,
        enabled: enabled
      }
    }
  end

  def handle_cast({:set_level, level}, state), do: %{state | level: level} |> noreply
  def handle_cast({:set_enabled, value}, state), do: %{state | enabled: value} |> noreply

  def handle_cast({msg_level, _, _}, %{enabled: false} = state) when msg_level in @valid_levels, do: noreply(state)
  def handle_cast({:debug, msg, metadata}, %{level: level} = state) when level in @debug_levels, do: Logger.debug(msg, metadata) |> noreply(state)
  def handle_cast({:info, msg, metadata},  %{level: level} = state) when level in @info_levels,  do: Logger.info(msg, metadata)  |> noreply(state)
  def handle_cast({:warn, msg, metadata},  %{level: level} = state) when level in @warn_levels,  do: Logger.warn(msg, metadata)  |> noreply(state)
  def handle_cast({:error, msg, metadata}, %{level: level} = state) when level in @error_levels, do: Logger.error(msg, metadata) |> noreply(state)
  def handle_cast({msg_level, _, _}, state) when msg_level in @valid_levels, do: noreply(state)

  defp noreply(state), do: {:noreply, state}
  defp noreply(_, state), do: noreply(state)
end
