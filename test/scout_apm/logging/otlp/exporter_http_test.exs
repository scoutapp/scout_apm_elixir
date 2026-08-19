defmodule ScoutApm.Logging.OTLP.ExporterHTTPTest do
  use ExUnit.Case

  alias ScoutApm.Logging.LogRecord
  alias ScoutApm.Logging.OTLP.Exporter

  # Exercises the real OTLP export path against a local server. Guards the
  # hackney API usage in Exporter.do_http_send/3, which must work on both the
  # hackney 1.x and 4.x lines (see issue #141).

  setup do
    bypass = Bypass.open()
    previous = Application.get_env(:scout_apm, :logs_endpoint)
    Application.put_env(:scout_apm, :logs_endpoint, "http://localhost:#{bypass.port}")

    on_exit(fn ->
      case previous do
        nil -> Application.delete_env(:scout_apm, :logs_endpoint)
        value -> Application.put_env(:scout_apm, :logs_endpoint, value)
      end
    end)

    {:ok, bypass: bypass}
  end

  test "export posts log records to /v1/logs", %{bypass: bypass} do
    test_pid = self()

    Bypass.expect_once(bypass, "POST", "/v1/logs", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      send(test_pid, {:posted, body})
      Plug.Conn.resp(conn, 200, "")
    end)

    assert :ok = Exporter.export([LogRecord.new(:info, "hello from the test suite")])

    assert_receive {:posted, body}, 5_000
    assert %{"resourceLogs" => _} = Jason.decode!(body)
  end

  test "export returns an error tuple on a non-2xx response", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/v1/logs", fn conn ->
      Plug.Conn.resp(conn, 500, "collector exploded")
    end)

    assert {:error, {:http_error, 500}} =
             Exporter.export([LogRecord.new(:info, "this one fails")])
  end
end
