defmodule ScoutApm.Instruments.FinchTelemetryTest do
  use ExUnit.Case

  alias ScoutApm.Instruments.FinchTelemetry

  setup do
    ScoutApm.TestCollector.clear_messages()
    :ok
  end

  describe "attach/0" do
    test "attaches telemetry handlers successfully" do
      # Detach first in case already attached
      try do
        FinchTelemetry.detach()
      rescue
        _ -> :ok
      end

      assert :ok = FinchTelemetry.attach()

      # Clean up
      FinchTelemetry.detach()
    end
  end

  describe "handle_event/4 for request stop" do
    test "records HTTP layer for successful request" do
      request = %{
        scheme: :https,
        host: "api.example.com",
        port: 443,
        path: "/users",
        method: "GET"
      }

      # 1ms in native time
      measurements = %{duration: 1_000_000}
      metadata = %{request: request, result: {:ok, %{status: 200}}}

      ScoutApm.TrackedRequest.start_layer("Controller", "test")
      FinchTelemetry.handle_event([:finch, :request, :stop], measurements, metadata, nil)
      ScoutApm.TrackedRequest.stop_layer()

      [%{BatchCommand: %{commands: commands}}] = ScoutApm.TestCollector.messages()

      # Verify HTTP operation span was created
      assert Enum.any?(commands, fn command ->
               span = Map.get(command, :StartSpan)
               span && Map.get(span, :operation) == "HTTP/GET"
             end)

      # Verify "url" tag for core agent domain extraction
      assert Enum.any?(commands, fn command ->
               tag = Map.get(command, :TagSpan)

               tag && Map.get(tag, :tag) == "url" &&
                 Map.get(tag, :value) == "https://api.example.com/users"
             end)

      # Verify "http.url" tag for compatibility
      assert Enum.any?(commands, fn command ->
               tag = Map.get(command, :TagSpan)

               tag && Map.get(tag, :tag) == "http.url" &&
                 Map.get(tag, :value) == "https://api.example.com/users"
             end)

      # Verify http.status_code tag was created
      assert Enum.any?(commands, fn command ->
               tag = Map.get(command, :TagSpan)
               tag && Map.get(tag, :tag) == "http.status_code" && Map.get(tag, :value) == "200"
             end)
    end

    test "records HTTP layer with POST method" do
      request = %{
        scheme: :https,
        host: "api.example.com",
        port: 443,
        path: "/users",
        method: :post
      }

      measurements = %{duration: 2_000_000}
      metadata = %{request: request, result: {:ok, %{status: 201}}}

      ScoutApm.TrackedRequest.start_layer("Controller", "test")
      FinchTelemetry.handle_event([:finch, :request, :stop], measurements, metadata, nil)
      ScoutApm.TrackedRequest.stop_layer()

      [%{BatchCommand: %{commands: commands}}] = ScoutApm.TestCollector.messages()

      assert Enum.any?(commands, fn command ->
               span = Map.get(command, :StartSpan)
               span && Map.get(span, :operation) == "HTTP/POST"
             end)

      assert Enum.any?(commands, fn command ->
               tag = Map.get(command, :TagSpan)
               tag && Map.get(tag, :tag) == "http.status_code" && Map.get(tag, :value) == "201"
             end)
    end

    test "omits default ports in URL" do
      request_https = %{
        scheme: :https,
        host: "api.example.com",
        port: 443,
        path: "/test",
        method: "GET"
      }

      request_http = %{
        scheme: :http,
        host: "api.example.com",
        port: 80,
        path: "/test",
        method: "GET"
      }

      request_custom = %{
        scheme: :https,
        host: "api.example.com",
        port: 8443,
        path: "/test",
        method: "GET"
      }

      measurements = %{duration: 1_000_000}

      ScoutApm.TrackedRequest.start_layer("Controller", "test")

      FinchTelemetry.handle_event(
        [:finch, :request, :stop],
        measurements,
        %{request: request_https, result: {:ok, %{status: 200}}},
        nil
      )

      FinchTelemetry.handle_event(
        [:finch, :request, :stop],
        measurements,
        %{request: request_http, result: {:ok, %{status: 200}}},
        nil
      )

      FinchTelemetry.handle_event(
        [:finch, :request, :stop],
        measurements,
        %{request: request_custom, result: {:ok, %{status: 200}}},
        nil
      )

      ScoutApm.TrackedRequest.stop_layer()

      [%{BatchCommand: %{commands: commands}}] = ScoutApm.TestCollector.messages()

      tag_values = fn tag_name ->
        commands
        |> Enum.filter(fn cmd -> Map.has_key?(cmd, :TagSpan) end)
        |> Enum.map(fn %{TagSpan: tag} -> tag end)
        |> Enum.filter(fn tag -> tag.tag == tag_name end)
        |> Enum.map(fn tag -> tag.value end)
      end

      # Both "url" and "http.url" tags should have the same values
      for tag_name <- ["url", "http.url"] do
        urls = tag_values.(tag_name)
        assert "https://api.example.com/test" in urls
        assert "http://api.example.com/test" in urls
        assert "https://api.example.com:8443/test" in urls
      end
    end

    test "skips Scout APM hosts" do
      scout_hosts = [
        %{
          scheme: :https,
          host: "errors.scoutapm.com",
          port: 443,
          path: "/errors",
          method: "POST"
        },
        %{scheme: :https, host: "apm.scoutapp.com", port: 443, path: "/checkin", method: "POST"},
        %{scheme: :https, host: "checkin.scoutapm.com", port: 443, path: "/", method: "POST"},
        %{
          scheme: :https,
          host: "otlp.scoutotel.com",
          port: 4318,
          path: "/v1/logs",
          method: "POST"
        }
      ]

      measurements = %{duration: 1_000_000}

      ScoutApm.TrackedRequest.start_layer("Controller", "test")

      for request <- scout_hosts do
        FinchTelemetry.handle_event(
          [:finch, :request, :stop],
          measurements,
          %{request: request, result: {:ok, %{status: 200}}},
          nil
        )
      end

      ScoutApm.TrackedRequest.stop_layer()

      [%{BatchCommand: %{commands: commands}}] = ScoutApm.TestCollector.messages()

      # Should only have the Controller span, no HTTP spans for Scout hosts
      http_spans =
        Enum.filter(commands, fn cmd ->
          case Map.get(cmd, :StartSpan) do
            %{operation: "HTTP/" <> _} -> true
            _ -> false
          end
        end)

      assert Enum.empty?(http_spans)
    end
  end

  describe "handle_event/4 for request exception" do
    test "records HTTP layer for failed request" do
      request = %{
        scheme: :https,
        host: "api.example.com",
        port: 443,
        path: "/users",
        method: "GET"
      }

      measurements = %{duration: 5_000_000}

      metadata = %{
        request: request,
        kind: :error,
        reason: %RuntimeError{message: "Connection refused"}
      }

      ScoutApm.TrackedRequest.start_layer("Controller", "test")
      FinchTelemetry.handle_event([:finch, :request, :exception], measurements, metadata, nil)
      ScoutApm.TrackedRequest.stop_layer()

      [%{BatchCommand: %{commands: commands}}] = ScoutApm.TestCollector.messages()

      # Verify HTTP operation span was created
      assert Enum.any?(commands, fn command ->
               span = Map.get(command, :StartSpan)
               span && Map.get(span, :operation) == "HTTP/GET"
             end)

      # Verify both url tags were created
      assert Enum.any?(commands, fn command ->
               tag = Map.get(command, :TagSpan)
               tag && Map.get(tag, :tag) == "url"
             end)

      assert Enum.any?(commands, fn command ->
               tag = Map.get(command, :TagSpan)
               tag && Map.get(tag, :tag) == "http.url"
             end)

      # No status code tag for exceptions
      refute Enum.any?(commands, fn command ->
               tag = Map.get(command, :TagSpan)
               tag && Map.get(tag, :tag) == "http.status_code"
             end)
    end
  end
end
