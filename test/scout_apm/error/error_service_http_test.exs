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
    Application.put_env(:scout_apm, :errors_host, "http://localhost:#{bypass.port}")

    on_exit(fn ->
      case previous do
        nil -> Application.delete_env(:scout_apm, :errors_host)
        value -> Application.put_env(:scout_apm, :errors_host, value)
      end
    end)

    # Clear anything other tests left in the shared queue so it doesn't get
    # flushed into this test's expectations.
    ErrorService.drain(5_000)

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
