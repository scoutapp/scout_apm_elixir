if Code.ensure_loaded?(Telemetry) || Code.ensure_loaded?(:telemetry) do
  defmodule ScoutApm.Instruments.FinchTelemetry do
    @moduledoc """
    Telemetry handler for Finch HTTP client instrumentation.

    Attaches to Finch telemetry events to track external HTTP requests:
    - HTTP requests appear as "HTTP" type layers (External Services)
    - Tracks URL, HTTP method, and response status code

    ## Usage

    In your application's `start/2` function:

        def start(_type, _args) do
          ScoutApm.Instruments.FinchTelemetry.attach()
          # ... rest of supervision tree
        end

    This will automatically instrument all Finch HTTP requests in your application,
    including those made through libraries built on Finch (like Req).

    ## What's Tracked

    - **Operation**: `HTTP/{method}` (e.g., "HTTP/GET", "HTTP/POST")
    - **URL**: The full URL of the request (sanitized)
    - **Status Code**: The HTTP response status code

    ## Configuration

    Requests to Scout APM's own endpoints are automatically excluded from tracking.
    """

    alias ScoutApm.TrackedRequest
    alias ScoutApm.Internal.Duration

    require Logger

    @events [
      [:finch, :request, :stop],
      [:finch, :request, :exception]
    ]

    # Scout APM hosts that should not be instrumented
    @scout_hosts [
      "errors.scoutapm.com",
      "apm.scoutapp.com",
      "checkin.scoutapm.com",
      "otlp.scoutotel.com"
    ]

    @doc """
    Attaches telemetry handlers for Finch HTTP request events.

    Call this once during application startup.
    """
    def attach do
      :telemetry.attach_many(
        "scout-apm-finch-telemetry",
        @events,
        &__MODULE__.handle_event/4,
        nil
      )
    end

    @doc """
    Detaches the telemetry handlers. Useful for testing.
    """
    def detach do
      :telemetry.detach("scout-apm-finch-telemetry")
    end

    # Request completed successfully
    def handle_event(
          [:finch, :request, :stop],
          %{duration: duration} = _measurements,
          %{request: request, result: result} = _metadata,
          _config
        ) do
      url = build_url(request)

      if should_instrument?(url) do
        method = normalize_method(request)
        status_code = extract_status_code(result)

        duration_struct =
          Duration.new(System.convert_time_unit(duration, :native, :microsecond), :microseconds)

        TrackedRequest.track_layer(
          "HTTP",
          method,
          duration_struct,
          http_method: method,
          http_url: url,
          http_status_code: status_code
        )
      end

      :ok
    end

    # Request failed with exception
    def handle_event(
          [:finch, :request, :exception],
          %{duration: duration} = _measurements,
          %{request: request, kind: _kind, reason: _reason} = _metadata,
          _config
        ) do
      url = build_url(request)

      if should_instrument?(url) do
        method = normalize_method(request)

        duration_struct =
          Duration.new(System.convert_time_unit(duration, :native, :microsecond), :microseconds)

        TrackedRequest.track_layer(
          "HTTP",
          method,
          duration_struct,
          http_method: method,
          http_url: url,
          http_status_code: nil
        )
      end

      :ok
    end

    # Catch-all for unhandled events
    def handle_event(_event, _measurements, _metadata, _config), do: :ok

    # Build URL from Finch request struct
    defp build_url(%{scheme: scheme, host: host, port: port, path: path}) do
      port_str = format_port(scheme, port)
      path_str = path || "/"
      "#{scheme}://#{host}#{port_str}#{path_str}"
    end

    defp build_url(_request), do: "Unknown"

    # Format port, omitting default ports
    defp format_port(:https, 443), do: ""
    defp format_port(:http, 80), do: ""
    defp format_port("https", 443), do: ""
    defp format_port("http", 80), do: ""
    defp format_port(_scheme, port), do: ":#{port}"

    # Normalize HTTP method to uppercase string
    defp normalize_method(%{method: method}) when is_binary(method), do: String.upcase(method)

    defp normalize_method(%{method: method}) when is_atom(method),
      do: method |> Atom.to_string() |> String.upcase()

    defp normalize_method(_), do: "UNKNOWN"

    # Extract status code from result
    defp extract_status_code({:ok, %{status: status}}), do: status
    defp extract_status_code(_), do: nil

    # Check if this URL should be instrumented (exclude Scout APM hosts)
    defp should_instrument?(url) when is_binary(url) do
      not Enum.any?(@scout_hosts, fn host -> String.contains?(url, host) end)
    end

    defp should_instrument?(_), do: true
  end
end
