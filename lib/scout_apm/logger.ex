defmodule ScoutApm.Logger do
  @moduledoc """
  Logger for all ScoutApm modules.

  Defaults to pass-through to the built-in Logger, but checks first if
  the agent is set to monitor: false, or set to a higher log level.

  Due to using Logger.log/2, ScoutApm.Logger calls will not be eliminated
  at compile-time.
  """

  require Logger

  @default_level :info

  # Support both :warn (deprecated) and :warning for backwards compatibility
  @valid_levels [:debug, :info, :warn, :warning, :error]

  # If you request to log a message at the left level, check if the
  # logger's current level is one of the right before letting it through
  #
  # For instance, if you ScoutApm.Logger.log(:warning, "foo"), it should be
  # printed if you're at warning, info, or debug levels
  #
  # Msg Lvl       Logger Lvl
  #  |              |
  #  |              |
  #  v              v
  @debug_levels [:debug]
  @info_levels [:debug, :info]
  @warn_levels [:debug, :info, :warn, :warning]
  @error_levels [:debug, :info, :warn, :warning, :error]

  @log_levels %{
    debug: @debug_levels,
    info: @info_levels,
    warn: @warn_levels,
    warning: @warn_levels,
    error: @error_levels
  }

  def log(level, chardata_or_fun, metadata \\ []) when level in @valid_levels do
    log_level = ScoutApm.Config.find(:log_level) || @default_level

    with {:ok, levels} <- logging_enabled() && Map.fetch(@log_levels, level),
         true <- log_level in levels do
      # Convert :warn to :warning for Elixir 1.15+ compatibility
      erlang_level = if level == :warn, do: :warning, else: level
      Logger.log(erlang_level, chardata_or_fun, metadata)
    else
      _ -> :ok
    end
  end

  defp logging_enabled do
    enabled = ScoutApm.Config.find(:monitor)
    key = ScoutApm.Config.find(:key)

    enabled && key
  end
end
