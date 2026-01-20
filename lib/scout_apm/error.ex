defmodule ScoutApm.Error do
  @moduledoc """
  Public API for capturing errors in Scout APM.

  Errors can be captured manually using `capture/1` or `capture/2`, or
  automatically via Phoenix telemetry handlers.

  ## Manual Error Capture

      try do
        some_risky_operation()
      rescue
        e ->
          ScoutApm.Error.capture(e, stacktrace: __STACKTRACE__)
          reraise e, __STACKTRACE__
      end

  ## With Additional Context

      try do
        process_user_request(user)
      rescue
        e ->
          ScoutApm.Error.capture(e,
            stacktrace: __STACKTRACE__,
            context: %{user_id: user.id},
            request_path: "/api/users",
            request_params: %{action: "update"}
          )
          reraise e, __STACKTRACE__
      end

  ## Configuration

  Error capture can be configured in your config:

      config :scout_apm,
        errors_enabled: true,
        errors_ignored_exceptions: [Phoenix.Router.NoRouteError],
        errors_filter_parameters: ["credit_card", "cvv"]

  ## Options

  All capture functions accept these options:

    * `:stacktrace` - The exception stacktrace. For best results, pass `__STACKTRACE__`
      from within a rescue block.
    * `:context` - A map of additional context to include with the error.
    * `:request_path` - The request path (e.g., "/api/users").
    * `:request_params` - A map of request parameters.
    * `:session` - A map of session data.
    * `:custom_controller` - Override the controller name.
    * `:custom_params` - A map of custom parameters.
  """

  alias ScoutApm.Error.ErrorData
  alias ScoutApm.Error.ErrorService

  @type capture_opts :: [
          stacktrace: Exception.stacktrace(),
          context: map(),
          request_path: String.t(),
          request_params: map(),
          session: map(),
          custom_controller: String.t(),
          custom_params: map()
        ]

  @doc """
  Captures an exception and sends it to Scout APM.

  The stacktrace will be captured automatically if not provided, but for
  best results, pass `__STACKTRACE__` from within a rescue block.

  Returns `:ok` on success.

  ## Examples

      try do
        do_something_risky()
      rescue
        e ->
          ScoutApm.Error.capture(e, stacktrace: __STACKTRACE__)
          reraise e, __STACKTRACE__
      end

      # With additional context
      ScoutApm.Error.capture(exception,
        stacktrace: __STACKTRACE__,
        context: %{user_id: 123},
        request_path: conn.request_path
      )
  """
  @spec capture(Exception.t(), capture_opts()) :: :ok
  def capture(exception, opts \\ []) when is_exception(exception) do
    if errors_enabled?() and not ignored_exception?(exception) do
      error_data = ErrorData.from_exception(exception, opts)
      ErrorService.send(error_data)
    end

    :ok
  end

  @doc """
  Captures an error from kind/reason/stacktrace tuple (as received in
  telemetry exception events).

  This is primarily used internally by telemetry handlers but can be called
  directly when handling exceptions in catch blocks.

  ## Examples

      try do
        do_something()
      catch
        kind, reason ->
          ScoutApm.Error.capture_from_telemetry(kind, reason, __STACKTRACE__)
          :erlang.raise(kind, reason, __STACKTRACE__)
      end
  """
  @spec capture_from_telemetry(
          kind :: :error | :throw | :exit,
          reason :: term(),
          stacktrace :: Exception.stacktrace(),
          capture_opts()
        ) :: :ok
  def capture_from_telemetry(kind, reason, stacktrace, opts \\ []) do
    if errors_enabled?() do
      error_data = ErrorData.from_telemetry(kind, reason, stacktrace, opts)

      if error_data && not ignored_exception_class?(error_data.exception_class) do
        ErrorService.send(error_data)
      end
    end

    :ok
  end

  @doc """
  Returns whether error capture is currently enabled.
  """
  @spec enabled?() :: boolean()
  def enabled? do
    errors_enabled?()
  end

  defp errors_enabled? do
    ScoutApm.Config.find(:errors_enabled) != false and
      ScoutApm.Config.find(:monitor) == true
  end

  defp ignored_exception?(exception) do
    ignored = ScoutApm.Config.find(:errors_ignored_exceptions) || []
    Enum.any?(ignored, fn mod -> is_struct(exception, mod) end)
  end

  defp ignored_exception_class?(class_name) do
    ignored = ScoutApm.Config.find(:errors_ignored_exceptions) || []

    Enum.any?(ignored, fn mod ->
      mod_name = Module.split(mod) |> List.last()
      mod_name == class_name
    end)
  end
end
