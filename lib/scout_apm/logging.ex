defmodule ScoutApm.Logging do
  @moduledoc """
  Public API for Scout APM's OTLP logging integration.

  This module provides functions to capture Elixir Logger messages,
  enrich them with Scout APM context (request ID, transaction name, custom tags),
  and send them to an OpenTelemetry collector via OTLP.

  ## Setup

  1. Add configuration to your `config/config.exs`:

      config :scout_apm,
        logs_enabled: true,
        logs_ingest_key: "your-logs-key"

  2. Attach the log handler in your application startup:

      def start(_type, _args) do
        ScoutApm.Logging.attach()
        # ... rest of supervision tree
      end

  ## Configuration Options

  - `:logs_enabled` - Enable/disable log capture (default: `false`)
  - `:logs_endpoint` - OTLP collector URL (default: `"https://otlp.scoutotel.com:4318"`)
  - `:logs_ingest_key` - Authentication key (falls back to `:key`)
  - `:logs_level` - Minimum log level to capture (default: `:info`)
  - `:logs_batch_size` - Logs per batch (default: `100`)
  - `:logs_max_queue_size` - Maximum queued logs (default: `5000`)
  - `:logs_flush_interval_ms` - Flush interval in ms (default: `5000`)
  - `:logs_filter_modules` - List of modules to exclude from capture

  ## Context Enrichment

  Logs captured within Scout-tracked requests are automatically enriched with:

  - `scout.request_id` - Unique request identifier
  - `scout.transaction_name` - e.g., "Controller/UserController#show"
  - `scout.layer_type` - Current operation type
  - `scout.layer_name` - Current operation name
  - `scout.tag.{key}` - Custom tags from `ScoutApm.Context.add/2`
  - `scout.user.{key}` - User context from `ScoutApm.Context.add_user/2`
  - `service.name` - Application name from config

  ## Example

      # Logs are automatically enriched when inside a Scout-tracked request
      def show(conn, %{"id" => id}) do
        user = Repo.get!(User, id)
        Logger.info("Fetched user", user_id: id)  # Will include Scout context
        render(conn, :show, user: user)
      end

      # Add custom context that appears in logs
      ScoutApm.Context.add("feature_flag", "new_checkout")
      Logger.info("Processing checkout")  # Includes scout.tag.feature_flag
  """

  alias ScoutApm.Logging.{LogHandler, LogService}

  @doc """
  Attaches the Scout APM log handler to capture Logger messages.

  ## Options

  - `:level` - Minimum log level to capture (default: from config or `:info`)
  - `:filter_modules` - Additional modules to exclude from capture

  ## Examples

      # Basic attach
      ScoutApm.Logging.attach()

      # With options
      ScoutApm.Logging.attach(level: :warning, filter_modules: [MyApp.Verbose])
  """
  @spec attach(keyword()) :: :ok | {:error, term()}
  def attach(opts \\ []) do
    LogHandler.attach(opts)
  end

  @doc """
  Detaches the Scout APM log handler.
  Logs will no longer be captured and sent to the OTLP collector.
  """
  @spec detach() :: :ok | {:error, term()}
  def detach do
    LogHandler.detach()
  end

  @doc """
  Returns true if the log handler is currently attached.
  """
  @spec attached?() :: boolean()
  def attached? do
    LogHandler.attached?()
  end

  @doc """
  Returns true if logging is enabled via configuration.
  """
  @spec enabled?() :: boolean()
  def enabled? do
    LogService.enabled?()
  end

  @doc """
  Forces an immediate flush of queued log records.
  Useful for testing or before application shutdown.
  """
  @spec flush() :: :ok
  def flush do
    LogService.flush()
  end

  @doc """
  Waits for the log queue to drain (all logs sent).
  Used during testing or graceful shutdown.

  ## Options

  - `timeout` - Maximum time to wait in milliseconds (default: 5000)

  Returns `:ok` if queue is empty, `:timeout` if timeout is reached.
  """
  @spec drain(timeout :: non_neg_integer()) :: :ok | :timeout
  def drain(timeout \\ 5_000) do
    LogService.drain(timeout)
  end

  @doc """
  Returns the current number of queued log records.
  """
  @spec queue_size() :: non_neg_integer()
  def queue_size do
    LogService.queue_size()
  end
end
