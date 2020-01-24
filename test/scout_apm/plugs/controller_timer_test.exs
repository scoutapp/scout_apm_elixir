defmodule ScoutApm.Plugs.ControllerTimerTest do
  use ExUnit.Case
  use Plug.Test
  alias ScoutApm.Plugs.ControllerTimer

  setup do
    ScoutApm.TestCollector.clear_messages()
    :ok
  end

  test "creates web trace" do
    conn(:get, "/")
    |> ScoutApm.TestPlugApp.call([])

    [%{BatchCommand: %{commands: commands}}] = ScoutApm.TestCollector.messages()

    assert Enum.any?(commands, fn command ->
             map = Map.get(command, :StartSpan)
             map && Map.get(map, :operation) == "Controller/PageController#index"
           end)
  end

  test "includes error metric on 500 response" do
    conn(:get, "/500")
    |> ScoutApm.TestPlugApp.call([])

    [%{BatchCommand: %{commands: commands}}] = ScoutApm.TestCollector.messages()

    assert Enum.any?(commands, fn command ->
             map = Map.get(command, :StartSpan)
             map && Map.get(map, :operation) == "Controller/PageController#500"
           end)

    assert Enum.any?(commands, fn command ->
             map = Map.get(command, :TagRequest)
             map && Map.get(map, :tag) == "error" && Map.get(map, :value) == "true"
           end)
  end

  test "adds ip context" do
    conn(:get, "/")
    |> ScoutApm.TestPlugApp.call([])

    [%{BatchCommand: %{commands: commands}}] = ScoutApm.TestCollector.messages()

    assert Enum.any?(commands, fn command ->
             map = Map.get(command, :StartSpan)
             map && Map.get(map, :operation) == "Controller/PageController#index"
           end)

    assert Enum.any?(commands, fn command ->
             map = Map.get(command, :TagRequest)
             map && Map.get(map, :tag) == :ip && is_binary(Map.get(map, :value))
           end)
  end

  test "adds ip context from x-forwarded-for header" do
    conn(:get, "/x-forwarded-for")
    |> ScoutApm.TestPlugApp.call([])

    [%{BatchCommand: %{commands: commands}}] = ScoutApm.TestCollector.messages()

    assert Enum.any?(commands, fn command ->
             map = Map.get(command, :StartSpan)
             map && Map.get(map, :operation) == "Controller/PageController#x-forwarded-for"
           end)

    assert Enum.any?(commands, fn command ->
             map = Map.get(command, :TagRequest)
             map && Map.get(map, :tag) == :ip && Map.get(map, :value) == "1.2.3.4"
           end)
  end

  test "does not create web trace when calling ScoutApm.TrackedRequest.ignore/0" do
    conn(:get, "/?ignore=true")
    |> ScoutApm.TestPlugApp.call([])

    assert ScoutApm.TestCollector.messages() == []
  end

  test "adds queue time context from headers" do
    # Set queue time to ~10 milliseconds before request returns
    queue_start =
      DateTime.utc_now()
      |> DateTime.to_unix(:millisecond)
      |> Kernel.-(10)

    conn(:get, "/x-forwarded-for")
    |> Plug.Conn.put_req_header("x-request-start", "t=#{queue_start}")
    |> ScoutApm.TestPlugApp.call([])

    [%{BatchCommand: %{commands: commands}}] = ScoutApm.TestCollector.messages()

    %{
      TagRequest: %{
        value: queue_time
      }
    } =
      Enum.find(commands, fn command ->
        map = Map.get(command, :TagRequest)

        map && Map.get(map, :tag) == "scout.queue_time_ns"
      end)

    # queue_time should be about 10 million nanoseconds
    # (between 10ms and 100ms)
    queue_time = String.to_integer(queue_time)
    assert queue_time >= 10_000_000
    assert queue_time < 100_000_000
  end

  test "adds queue time context from headers in nginx format" do
    # Set queue time to ~10 milliseconds before request returns
    queue_start =
      DateTime.utc_now()
      |> DateTime.to_unix(:millisecond)
      |> Kernel.-(10)

    conn(:get, "/x-forwarded-for")
    |> Plug.Conn.put_req_header("x-queue-start", "#{queue_start}")
    |> ScoutApm.TestPlugApp.call([])

    [%{BatchCommand: %{commands: commands}}] = ScoutApm.TestCollector.messages()

    %{
      TagRequest: %{
        value: queue_time
      }
    } =
      Enum.find(commands, fn command ->
        map = Map.get(command, :TagRequest)

        map && Map.get(map, :tag) == "scout.queue_time_ns"
      end)

    # queue_time should be about 10 million nanoseconds
    # (between 10ms and 100ms)
    queue_time = String.to_integer(queue_time)
    assert queue_time >= 10_000_000
    assert queue_time < 100_000_000
  end

  describe "action_name/1" do
    setup do
      conn = conn(:get, "/") |> ScoutApm.TestPlugApp.call([])

      [conn: conn]
    end

    test "configured to trim app module name (default)", %{conn: conn} do
      assert ControllerTimer.action_name(conn, []) == "PageController#index"
    end

    test "configured to not trim app module name", %{conn: conn} do
      assert ControllerTimer.action_name(conn, include_application_name: true) ==
               "MyTestApp.PageController#index"
    end
  end
end
