if Code.ensure_loaded?(Telemetry) || Code.ensure_loaded?(:telemetry) do
  defmodule ScoutApm.Instruments.PhoenixErrorTelemetry do
    @moduledoc """
    Telemetry handler for automatic Phoenix error capture.

    Attaches to Phoenix telemetry events to automatically capture:
    - Router dispatch exceptions
    - Error rendering events

    ## Usage

    In your application's `start/2` function:

        def start(_type, _args) do
          ScoutApm.Instruments.PhoenixErrorTelemetry.attach()
          # ... rest of supervision tree
        end

    This will automatically capture all unhandled exceptions in Phoenix routes.
    """

    @events [
      [:phoenix, :router_dispatch, :exception],
      [:phoenix, :error_rendered]
    ]

    @doc """
    Attaches telemetry handlers for Phoenix error events.
    Call this once during application startup.
    """
    def attach do
      :telemetry.attach_many(
        "scout-apm-phoenix-error-telemetry",
        @events,
        &__MODULE__.handle_event/4,
        nil
      )
    end

    @doc """
    Detaches the telemetry handlers. Useful for testing.
    """
    def detach do
      :telemetry.detach("scout-apm-phoenix-error-telemetry")
    end

    # Router dispatch exception - captures full exception info
    def handle_event(
          [:phoenix, :router_dispatch, :exception],
          _measurements,
          %{conn: conn, kind: kind, reason: reason, stacktrace: stacktrace} = _metadata,
          _config
        ) do
      # Also mark the tracked request as having an error
      ScoutApm.TrackedRequest.mark_error()

      # Extract request information from conn
      opts = [
        request_path: conn.request_path,
        request_params: extract_params(conn),
        session: extract_session(conn),
        custom_controller: extract_controller(conn)
      ]

      ScoutApm.Error.capture_from_telemetry(kind, reason, stacktrace, opts)
    end

    # Error rendered - captures when Phoenix renders an error response
    # This is useful for catching errors that bubble up to the error view
    def handle_event(
          [:phoenix, :error_rendered],
          _measurements,
          %{status: status, kind: kind, reason: reason, stacktrace: stacktrace} = metadata,
          _config
        )
        when status >= 500 do
      conn = Map.get(metadata, :conn)

      opts =
        if conn do
          [
            request_path: conn.request_path,
            request_params: extract_params(conn),
            session: extract_session(conn),
            custom_controller: extract_controller(conn)
          ]
        else
          []
        end

      ScoutApm.Error.capture_from_telemetry(kind, reason, stacktrace, opts)
    end

    def handle_event([:phoenix, :error_rendered], _measurements, _metadata, _config) do
      # Ignore non-500 errors (4xx client errors)
      :ok
    end

    # Catch-all for unhandled events
    def handle_event(_event, _measurements, _metadata, _config), do: :ok

    # Private helpers

    defp extract_params(conn) do
      try do
        conn.params
      rescue
        _ -> nil
      end
    end

    defp extract_session(conn) do
      try do
        Plug.Conn.get_session(conn)
      rescue
        _ -> nil
      end
    end

    defp extract_controller(conn) do
      controller = conn.private[:phoenix_controller]
      action = conn.private[:phoenix_action]

      if controller do
        controller_name =
          controller
          |> Module.split()
          |> Enum.drop(1)
          |> Enum.join(".")

        if action do
          "#{controller_name}##{action}"
        else
          controller_name
        end
      else
        nil
      end
    end
  end
end
