if Code.ensure_loaded?(Telemetry) || Code.ensure_loaded?(:telemetry) do
  defmodule ScoutApm.Instruments.TeslaTelemetry do
    @moduledoc """
    Telemetry handler for Tesla HTTP client instrumentation.

    Attaches to Tesla telemetry events to track external HTTP requests:
    - HTTP requests appear as "HTTP" type layers (External Services)
    - Tracks URL, HTTP method, and response status code

    ## Prerequisites

    Your Tesla client must include the Telemetry middleware. Add it to your client:

        defmodule MyApp.ApiClient do
          use Tesla

          plug Tesla.Middleware.Telemetry
          plug Tesla.Middleware.BaseUrl, "https://api.example.com"
          # ... other middleware
        end

    **Important:** Place `Tesla.Middleware.Telemetry` as close as possible to the end
    of the middleware stack to ensure accurate timing measurements.

    ## Usage

    In your application's `start/2` function:

        def start(_type, _args) do
          ScoutApm.Instruments.TeslaTelemetry.attach()
          # ... rest of supervision tree
        end

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
      [:tesla, :request, :stop],
      [:tesla, :request, :exception]
    ]

    # Scout APM hosts that should not be instrumented
    @scout_hosts [
      "errors.scoutapm.com",
      "apm.scoutapp.com",
      "checkin.scoutapm.com",
      "otlp.scoutotel.com"
    ]

    @doc """
    Attaches telemetry handlers for Tesla HTTP request events.

    Call this once during application startup.
    """
    def attach do
      :telemetry.attach_many(
        "scout-apm-tesla-telemetry",
        @events,
        &__MODULE__.handle_event/4,
        nil
      )
    end

    @doc """
    Detaches the telemetry handlers. Useful for testing.
    """
    def detach do
      :telemetry.detach("scout-apm-tesla-telemetry")
    end

    # Request completed with error in metadata — must come before success clause
    # since %{env: env} would also match maps containing an :error key
    def handle_event(
          [:tesla, :request, :stop],
          %{duration: duration} = _measurements,
          %{env: env, error: _error} = _metadata,
          _config
        ) do
      url = build_url(env)

      if should_instrument?(url) do
        method = normalize_method(env)

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

    # Request completed successfully
    def handle_event(
          [:tesla, :request, :stop],
          %{duration: duration} = _measurements,
          %{env: env} = _metadata,
          _config
        ) do
      url = build_url(env)

      if should_instrument?(url) do
        method = normalize_method(env)
        status_code = extract_status_code(env)

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
          [:tesla, :request, :exception],
          %{duration: duration} = _measurements,
          %{env: env} = _metadata,
          _config
        ) do
      url = build_url(env)

      if should_instrument?(url) do
        method = normalize_method(env)

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

    # Build URL from Tesla.Env struct, stripping query strings to avoid leaking sensitive data
    defp build_url(%{url: url}) when is_binary(url) do
      case URI.parse(url) do
        %URI{scheme: scheme, host: host, port: port, path: path}
        when is_binary(scheme) and is_binary(host) ->
          port_str = format_port(scheme, port)
          path_str = path || "/"
          "#{scheme}://#{host}#{port_str}#{path_str}"

        _ ->
          url
      end
    end

    defp build_url(_env), do: "Unknown"

    # Format port, omitting default ports
    defp format_port("https", 443), do: ""
    defp format_port("http", 80), do: ""
    defp format_port(_, nil), do: ""
    defp format_port(_, port), do: ":#{port}"

    # Normalize HTTP method to uppercase string
    defp normalize_method(%{method: method}) when is_atom(method),
      do: method |> Atom.to_string() |> String.upcase()

    defp normalize_method(%{method: method}) when is_binary(method), do: String.upcase(method)
    defp normalize_method(_), do: "UNKNOWN"

    # Extract status code from Tesla.Env
    defp extract_status_code(%{status: status}) when is_integer(status), do: status
    defp extract_status_code(_), do: nil

    # Check if this URL should be instrumented (exclude Scout APM hosts)
    defp should_instrument?(url) when is_binary(url) do
      not Enum.any?(@scout_hosts, fn host -> String.contains?(url, host) end)
    end

    defp should_instrument?(_), do: true
  end
end
