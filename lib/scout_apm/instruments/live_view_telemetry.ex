if Code.ensure_loaded?(Telemetry) || Code.ensure_loaded?(:telemetry) do
  defmodule ScoutApm.Instruments.LiveViewTelemetry do
    @moduledoc """
    Telemetry handler for Phoenix LiveView instrumentation.

    Attaches to LiveView telemetry events to track:
    - LiveView mounts (as "LiveView" type transactions)
    - handle_event callbacks (as timed layers within transactions)
    - handle_params callbacks (as timed layers within transactions)

    ## Usage

    In your application's `start/2` function:

        def start(_type, _args) do
          ScoutApm.Instruments.LiveViewTelemetry.attach()
          # ... rest of supervision tree
        end

    This will automatically instrument all LiveView modules in your application.
    """

    alias ScoutApm.TrackedRequest
    alias ScoutApm.Internal.Layer

    require Logger

    @events [
      [:phoenix, :live_view, :mount, :start],
      [:phoenix, :live_view, :mount, :stop],
      [:phoenix, :live_view, :mount, :exception],
      [:phoenix, :live_view, :handle_event, :start],
      [:phoenix, :live_view, :handle_event, :stop],
      [:phoenix, :live_view, :handle_event, :exception],
      [:phoenix, :live_view, :handle_params, :start],
      [:phoenix, :live_view, :handle_params, :stop],
      [:phoenix, :live_view, :handle_params, :exception]
    ]

    @doc """
    Attaches telemetry handlers for LiveView events.

    Call this once during application startup.
    """
    def attach do
      Logger.info("[ScoutApm.LiveViewTelemetry] Attaching to events: #{inspect(@events)}")

      result =
        :telemetry.attach_many(
          "scout-apm-live-view-telemetry",
          @events,
          &__MODULE__.handle_event/4,
          nil
        )

      Logger.info("[ScoutApm.LiveViewTelemetry] Attach result: #{inspect(result)}")
      result
    end

    @doc """
    Detaches the telemetry handlers. Useful for testing.
    """
    def detach do
      :telemetry.detach("scout-apm-live-view-telemetry")
    end

    # Mount start - begins a new transaction
    def handle_event(
          [:phoenix, :live_view, :mount, :start],
          _measurements,
          %{socket: socket} = _metadata,
          _config
        ) do
      view_module = socket.view
      name = live_view_name(view_module, "mount")

      # Check existing state before starting
      existing = Process.get(:scout_apm_request)

      Logger.info("scout_liveview mount:start",
        scout_event: "mount:start",
        view: inspect(view_module),
        name: name,
        existing_request: existing != nil
      )

      # Use "Controller" type so Scout APM backend recognizes it as a web transaction
      result = TrackedRequest.start_layer("Controller", name)
      after_start = Process.get(:scout_apm_request)

      Logger.info("scout_liveview mount:start complete",
        scout_event: "mount:start:after",
        layers: after_start && length(after_start.layers),
        success: result != nil
      )

      result
    end

    # Mount stop - completes the transaction
    def handle_event(
          [:phoenix, :live_view, :mount, :stop],
          measurements,
          %{socket: socket} = _metadata,
          _config
        ) do
      view_module = socket.view
      name = live_view_name(view_module, "mount")
      uri = get_uri_from_socket(socket)

      before_stop = Process.get(:scout_apm_request)

      Logger.info("scout_liveview mount:stop",
        scout_event: "mount:stop:before",
        view: inspect(view_module),
        name: name,
        uri: uri,
        duration_ns: measurements[:duration],
        layers: before_stop && length(before_stop.layers)
      )

      result =
        TrackedRequest.stop_layer(fn layer ->
          layer
          |> Layer.update_name(name)
          |> maybe_update_uri(uri)
        end)

      after_stop = Process.get(:scout_apm_request)

      Logger.info("scout_liveview mount:stop complete",
        scout_event: "mount:stop:after",
        request_cleared: after_stop == nil,
        result: inspect(result)
      )

      result
    end

    # Mount exception - marks error and completes
    def handle_event(
          [:phoenix, :live_view, :mount, :exception],
          _measurements,
          %{socket: socket, kind: kind, reason: reason, stacktrace: stacktrace} = _metadata,
          _config
        ) do
      view_module = socket.view
      name = live_view_name(view_module, "mount")

      TrackedRequest.mark_error()

      # Capture full error details
      ScoutApm.Error.capture_from_telemetry(kind, reason, stacktrace,
        request_path: get_uri_from_socket(socket),
        custom_controller: name
      )

      TrackedRequest.stop_layer(fn layer ->
        layer
        |> Layer.update_name(name)
      end)
    end

    # Handle event start - begins a new transaction for each user interaction
    def handle_event(
          [:phoenix, :live_view, :handle_event, :start],
          _measurements,
          %{socket: socket, event: event} = _metadata,
          _config
        ) do
      view_module = socket.view
      name = live_view_name(view_module, "handle_event:#{event}")

      Logger.info(
        "[ScoutApm.LiveViewTelemetry] handle_event:start - view=#{inspect(view_module)} event=#{event} name=#{name}"
      )

      # Use "Controller" type so Scout APM backend recognizes it as a web transaction
      TrackedRequest.start_layer("Controller", name)
    end

    # Handle event stop
    def handle_event(
          [:phoenix, :live_view, :handle_event, :stop],
          measurements,
          %{socket: socket, event: event} = _metadata,
          _config
        ) do
      view_module = socket.view
      name = live_view_name(view_module, "handle_event:#{event}")
      uri = get_uri_from_socket(socket)

      Logger.info(
        "[ScoutApm.LiveViewTelemetry] handle_event:stop - view=#{inspect(view_module)} event=#{event} name=#{name} duration=#{inspect(measurements[:duration])}"
      )

      TrackedRequest.stop_layer(fn layer ->
        layer
        |> Layer.update_name(name)
        |> maybe_update_uri(uri)
      end)
    end

    # Handle event exception
    def handle_event(
          [:phoenix, :live_view, :handle_event, :exception],
          _measurements,
          %{socket: socket, event: event, kind: kind, reason: reason, stacktrace: stacktrace} =
            _metadata,
          _config
        ) do
      view_module = socket.view
      name = live_view_name(view_module, "handle_event:#{event}")

      TrackedRequest.mark_error()

      # Capture full error details
      ScoutApm.Error.capture_from_telemetry(kind, reason, stacktrace,
        request_path: get_uri_from_socket(socket),
        custom_controller: name
      )

      TrackedRequest.stop_layer(fn layer ->
        layer
        |> Layer.update_name(name)
      end)
    end

    # Handle params start
    def handle_event(
          [:phoenix, :live_view, :handle_params, :start],
          _measurements,
          %{socket: socket} = _metadata,
          _config
        ) do
      view_module = socket.view
      name = live_view_name(view_module, "handle_params")

      # Use "Controller" type so Scout APM backend recognizes it as a web transaction
      TrackedRequest.start_layer("Controller", name)
    end

    # Handle params stop
    def handle_event(
          [:phoenix, :live_view, :handle_params, :stop],
          _measurements,
          %{socket: socket, uri: uri} = _metadata,
          _config
        ) do
      view_module = socket.view
      name = live_view_name(view_module, "handle_params")

      TrackedRequest.stop_layer(fn layer ->
        layer
        |> Layer.update_name(name)
        |> Layer.update_uri(uri)
      end)
    end

    # Handle params exception
    def handle_event(
          [:phoenix, :live_view, :handle_params, :exception],
          _measurements,
          %{socket: socket, kind: kind, reason: reason, stacktrace: stacktrace} = _metadata,
          _config
        ) do
      view_module = socket.view
      name = live_view_name(view_module, "handle_params")

      TrackedRequest.mark_error()

      # Capture full error details
      ScoutApm.Error.capture_from_telemetry(kind, reason, stacktrace,
        request_path: get_uri_from_socket(socket),
        custom_controller: name
      )

      TrackedRequest.stop_layer(fn layer ->
        layer
        |> Layer.update_name(name)
      end)
    end

    # Catch-all for unhandled events
    def handle_event(_event, _measurements, _metadata, _config), do: :ok

    # Helper to format LiveView module name
    defp live_view_name(nil, action), do: "Unknown##{action}"

    defp live_view_name(view_module, action) do
      view_module
      |> Module.split()
      # Drop the app name prefix (e.g., "GaggleWeb")
      |> Enum.drop(1)
      |> Enum.join(".")
      |> Kernel.<>("##{action}")
    end

    defp get_uri_from_socket(socket) do
      case socket do
        %{host_uri: %URI{path: path}} when is_binary(path) -> path
        _ -> nil
      end
    end

    defp maybe_update_uri(layer, nil), do: layer
    defp maybe_update_uri(layer, uri), do: Layer.update_uri(layer, uri)
  end
end
