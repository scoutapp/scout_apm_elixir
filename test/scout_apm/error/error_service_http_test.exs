defmodule ScoutApm.Error.ErrorServiceHTTPTest do
  use ExUnit.Case

  alias ScoutApm.Error.ErrorData
  alias ScoutApm.Error.ErrorService

  # Exercises the real HTTP reporting path against a local server. Guards the
  # hackney API usage in ErrorService.do_http_send/2, which must work on both
  # the hackney 1.x and 4.x lines (see issue #141).

  setup do
    bypass = Bypass.open()
    previous = Application.get_env(:scout_apm, :errors_host)

    # Clear anything other tests left in the shared queue BEFORE pointing
    # errors_host at this test's server — the drain itself sends queued
    # batches, and a batch arriving at Bypass before an expectation is
    # declared fails the test ("got an HTTP request but wasn't expecting
    # one"). Draining against a dead port fails fast, and failed batches are
    # dequeued, leaving the queue empty.
    Application.put_env(:scout_apm, :errors_host, "http://127.0.0.1:9")
    ErrorService.drain(5_000)

    Application.put_env(:scout_apm, :errors_host, "http://localhost:#{bypass.port}")

    on_exit(fn ->
      case previous do
        nil -> Application.delete_env(:scout_apm, :errors_host)
        value -> Application.put_env(:scout_apm, :errors_host, value)
      end
    end)

    {:ok, bypass: bypass}
  end

  test "flush posts the gzipped error batch", %{bypass: bypass} do
    test_pid = self()

    Bypass.expect(bypass, "POST", "/apps/error.scout", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      send(test_pid, {:posted, body})
      Plug.Conn.resp(conn, 200, "")
    end)

    error_data = ErrorData.from_exception(%RuntimeError{message: "boom"}, stacktrace: [])
    ErrorService.send(error_data)

    assert ErrorService.flush() == :ok

    assert_receive {:posted, body}, 5_000

    payload = body |> :zlib.gunzip() |> Jason.decode!()
    assert payload["notifier"] == "scout_apm_elixir"
    assert [problem | _] = payload["problems"]
    assert problem["message"] =~ "boom"
  end
end
