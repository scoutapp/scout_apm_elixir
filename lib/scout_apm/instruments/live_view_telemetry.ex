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
      :telemetry.attach_many(
        "scout-apm-live-view-telemetry",
        @events,
        &__MODULE__.handle_event/4,
        nil
      )
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

      TrackedRequest.start_layer("LiveView", name)
    end

    # Mount stop - completes the transaction
    def handle_event(
          [:phoenix, :live_view, :mount, :stop],
          _measurements,
          %{socket: socket} = _metadata,
          _config
        ) do
      view_module = socket.view
      name = live_view_name(view_module, "mount")
      uri = get_uri_from_socket(socket)

      TrackedRequest.stop_layer(fn layer ->
        layer
        |> Layer.update_name(name)
        |> maybe_update_uri(uri)
      end)
    end

    # Mount exception - marks error and completes
    def handle_event(
          [:phoenix, :live_view, :mount, :exception],
          _measurements,
          %{socket: socket} = _metadata,
          _config
        ) do
      view_module = socket.view
      name = live_view_name(view_module, "mount")

      TrackedRequest.mark_error()

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

      TrackedRequest.start_layer("LiveView", name)
    end

    # Handle event stop
    def handle_event(
          [:phoenix, :live_view, :handle_event, :stop],
          _measurements,
          %{socket: socket, event: event} = _metadata,
          _config
        ) do
      view_module = socket.view
      name = live_view_name(view_module, "handle_event:#{event}")
      uri = get_uri_from_socket(socket)

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
          %{socket: socket, event: event} = _metadata,
          _config
        ) do
      view_module = socket.view
      name = live_view_name(view_module, "handle_event:#{event}")

      TrackedRequest.mark_error()

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

      TrackedRequest.start_layer("LiveView", name)
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
          %{socket: socket} = _metadata,
          _config
        ) do
      view_module = socket.view
      name = live_view_name(view_module, "handle_params")

      TrackedRequest.mark_error()

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
      |> Enum.drop(1)  # Drop the app name prefix (e.g., "GaggleWeb")
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
