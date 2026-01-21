defmodule ScoutApm.Logging.LogHandler do
  @moduledoc """
  Erlang :logger handler for capturing log events and sending them to OTLP.

  This handler runs in the client process (the process that calls Logger),
  which allows us to directly access Scout APM context from the process dictionary.

  ## Usage

      # Attach the handler
      ScoutApm.Logging.LogHandler.attach()

      # Detach the handler
      ScoutApm.Logging.LogHandler.detach()

  ## Configuration

  The handler respects the following config options:
  - `:logs_enabled` - Must be true for handler to process logs
  - `:logs_level` - Minimum level to capture (default: :info)
  - `:logs_filter_modules` - List of modules to exclude from capture
  """

  alias ScoutApm.Logging.{LogRecord, LogService, ContextExtractor}
  alias ScoutApm.Logging.OTLP.Severity

  @handler_id :scout_apm_log_handler
  @recursion_flag :scout_apm_log_handler_active

  # Scout modules to always filter out (prevent recursion)
  @internal_modules [
    ScoutApm.Logging.LogHandler,
    ScoutApm.Logging.LogService,
    ScoutApm.Logging.OTLP.Exporter,
    ScoutApm.Logging.OTLP.Encoder,
    ScoutApm.Logger
  ]

  @doc """
  Attaches the log handler to the Erlang :logger system.
  Returns :ok on success, {:error, reason} on failure.
  """
  @spec attach(keyword()) :: :ok | {:error, term()}
  def attach(opts \\ []) do
    config = %{
      level: Keyword.get(opts, :level, get_default_level()),
      filter_modules: Keyword.get(opts, :filter_modules, get_filter_modules())
    }

    case :logger.add_handler(@handler_id, __MODULE__, %{config: config}) do
      :ok ->
        ScoutApm.Logger.log(:info, "Scout APM log handler attached")
        :ok

      {:error, {:already_exist, _}} ->
        :ok

      {:error, reason} = error ->
        ScoutApm.Logger.log(:debug, "Failed to attach Scout APM log handler: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Detaches the log handler from the Erlang :logger system.
  """
  @spec detach() :: :ok | {:error, term()}
  def detach do
    case :logger.remove_handler(@handler_id) do
      :ok ->
        ScoutApm.Logger.log(:info, "Scout APM log handler detached")
        :ok

      {:error, {:not_found, _}} ->
        :ok

      {:error, reason} = error ->
        ScoutApm.Logger.log(:debug, "Failed to detach Scout APM log handler: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Checks if the handler is currently attached.
  """
  @spec attached?() :: boolean()
  def attached? do
    @handler_id in :logger.get_handler_ids()
  end

  @doc """
  Returns the handler ID used for registration.
  """
  @spec handler_id() :: atom()
  def handler_id, do: @handler_id

  # Erlang :logger handler callbacks

  @doc false
  def adding_handler(config) do
    {:ok, config}
  end

  @doc false
  def removing_handler(_config) do
    :ok
  end

  @doc false
  def changing_config(_action, _old_config, new_config) do
    {:ok, new_config}
  end

  # Main callback - receives log events in the client process.
  # This is where we capture Scout context from the process dictionary.
  @doc false
  def log(event, config) do
    # Prevent recursion - if we're already processing a log, skip
    if Process.get(@recursion_flag) do
      :ok
    else
      try do
        Process.put(@recursion_flag, true)
        do_log(event, config)
      after
        Process.delete(@recursion_flag)
      end
    end
  end

  # Private functions

  defp do_log(event, config) do
    # Check if logging is enabled
    unless LogService.enabled?() do
      :ok
    else
      handler_config = get_handler_config(config)

      # Check if this event should be processed
      if should_process?(event, handler_config) do
        # Extract Scout context from current process
        scout_context = ContextExtractor.extract()

        # Create log record
        record = LogRecord.from_logger_event(event, scout_context)

        # Send to service for batching
        LogService.send(record)
      end

      :ok
    end
  end

  defp get_handler_config(%{config: config}), do: config
  defp get_handler_config(_), do: %{}

  defp should_process?(event, config) do
    level = Map.get(event, :level, :info)
    min_level = Map.get(config, :level, :info)
    filter_modules = Map.get(config, :filter_modules, [])

    meets_level?(level, min_level) and
      not from_filtered_module?(event, filter_modules)
  end

  defp meets_level?(level, min_level) do
    Severity.meets_level?(level, min_level)
  end

  defp from_filtered_module?(event, user_filter_modules) do
    all_filtered = @internal_modules ++ user_filter_modules

    case get_event_module(event) do
      nil -> false
      module -> module in all_filtered
    end
  end

  defp get_event_module(%{meta: %{mfa: {module, _fun, _arity}}}), do: module
  defp get_event_module(%{meta: %{module: module}}), do: module
  defp get_event_module(_), do: nil

  defp get_default_level do
    ScoutApm.Config.find(:logs_level) || :info
  end

  defp get_filter_modules do
    ScoutApm.Config.find(:logs_filter_modules) || []
  end
end
