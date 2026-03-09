defmodule ScoutApm.Instruments.TeslaTelemetryTest do
  use ExUnit.Case

  alias ScoutApm.Instruments.TeslaTelemetry

  setup do
    ScoutApm.TestCollector.clear_messages()
    :ok
  end

  describe "attach/0" do
    test "attaches telemetry handlers successfully" do
      # Detach first in case already attached
      try do
        TeslaTelemetry.detach()
      rescue
        _ -> :ok
      end

      assert :ok = TeslaTelemetry.attach()

      # Clean up
      TeslaTelemetry.detach()
    end
  end

  describe "handle_event/4 for request stop" do
    test "records HTTP layer for successful request" do
      env = %{
        url: "https://api.example.com/users",
        method: :get,
        status: 200
      }

      # 1ms in native time
      measurements = %{duration: 1_000_000}
      metadata = %{env: env}

      ScoutApm.TrackedRequest.start_layer("Controller", "test")
      TeslaTelemetry.handle_event([:tesla, :request, :stop], measurements, metadata, nil)
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
      env = %{
        url: "https://api.example.com/users",
        method: :post,
        status: 201
      }

      measurements = %{duration: 2_000_000}
      metadata = %{env: env}

      ScoutApm.TrackedRequest.start_layer("Controller", "test")
      TeslaTelemetry.handle_event([:tesla, :request, :stop], measurements, metadata, nil)
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

    test "handles string method values" do
      env = %{
        url: "https://api.example.com/users",
        method: "PUT",
        status: 200
      }

      measurements = %{duration: 1_000_000}
      metadata = %{env: env}

      ScoutApm.TrackedRequest.start_layer("Controller", "test")
      TeslaTelemetry.handle_event([:tesla, :request, :stop], measurements, metadata, nil)
      ScoutApm.TrackedRequest.stop_layer()

      [%{BatchCommand: %{commands: commands}}] = ScoutApm.TestCollector.messages()

      assert Enum.any?(commands, fn command ->
               span = Map.get(command, :StartSpan)
               span && Map.get(span, :operation) == "HTTP/PUT"
             end)
    end

    test "strips query strings from URLs" do
      env = %{
        url: "https://api.example.com/users?api_key=secret123&page=1",
        method: :get,
        status: 200
      }

      measurements = %{duration: 1_000_000}
      metadata = %{env: env}

      ScoutApm.TrackedRequest.start_layer("Controller", "test")
      TeslaTelemetry.handle_event([:tesla, :request, :stop], measurements, metadata, nil)
      ScoutApm.TrackedRequest.stop_layer()

      [%{BatchCommand: %{commands: commands}}] = ScoutApm.TestCollector.messages()

      # URL should have query string stripped
      assert Enum.any?(commands, fn command ->
               tag = Map.get(command, :TagSpan)

               tag && Map.get(tag, :tag) == "url" &&
                 Map.get(tag, :value) == "https://api.example.com/users"
             end)

      # Should NOT contain query parameters
      refute Enum.any?(commands, fn command ->
               tag = Map.get(command, :TagSpan)

               tag && Map.get(tag, :tag) == "url" &&
                 String.contains?(Map.get(tag, :value, ""), "secret123")
             end)
    end

    test "skips Scout APM hosts" do
      scout_envs = [
        %{url: "https://errors.scoutapm.com/errors", method: :post, status: 200},
        %{url: "https://apm.scoutapp.com/checkin", method: :post, status: 200},
        %{url: "https://checkin.scoutapm.com/", method: :post, status: 200},
        %{url: "https://otlp.scoutotel.com:4318/v1/logs", method: :post, status: 200}
      ]

      measurements = %{duration: 1_000_000}

      ScoutApm.TrackedRequest.start_layer("Controller", "test")

      for env <- scout_envs do
        TeslaTelemetry.handle_event([:tesla, :request, :stop], measurements, %{env: env}, nil)
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

    test "handles request with error in metadata" do
      env = %{
        url: "https://api.example.com/users",
        method: :get,
        status: nil
      }

      measurements = %{duration: 5_000_000}
      metadata = %{env: env, error: {:error, :econnrefused}}

      ScoutApm.TrackedRequest.start_layer("Controller", "test")
      TeslaTelemetry.handle_event([:tesla, :request, :stop], measurements, metadata, nil)
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

      # No status code tag for errors
      refute Enum.any?(commands, fn command ->
               tag = Map.get(command, :TagSpan)
               tag && Map.get(tag, :tag) == "http.status_code"
             end)
    end
  end

  describe "handle_event/4 for request exception" do
    test "records HTTP layer for failed request" do
      env = %{
        url: "https://api.example.com/users",
        method: :get
      }

      measurements = %{duration: 5_000_000}

      metadata = %{
        env: env,
        kind: :error,
        reason: %RuntimeError{message: "Connection refused"},
        stacktrace: []
      }

      ScoutApm.TrackedRequest.start_layer("Controller", "test")
      TeslaTelemetry.handle_event([:tesla, :request, :exception], measurements, metadata, nil)
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
