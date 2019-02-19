defmodule ScoutApm.Plugs.ControllerTimerTest do
  use ExUnit.Case
  use Plug.Test

  setup do
    ScoutApm.TestCollector.clear_messages()
    :ok
  end

  test "creates web trace" do
    conn(:get, "/")
    |> ScoutApm.TestPlugApp.call([])

    [%{BatchCommand: %{commands: commands}}] = ScoutApm.TestCollector.messages()

    assert Enum.any?(commands, fn(command) ->
      map = Map.get(command, :StartSpan)
      map && Map.get(map, :operation) == "Controller/PageController#index"
    end)
  end

  test "includes error metric on 500 response" do
    conn(:get, "/500")
    |> ScoutApm.TestPlugApp.call([])

    [%{BatchCommand: %{commands: commands}}] = ScoutApm.TestCollector.messages()

    assert Enum.any?(commands, fn(command) ->
      map = Map.get(command, :StartSpan)
      map && Map.get(map, :operation) ==  "Controller/PageController#500"
    end)
    assert Enum.any?(commands, fn(command) ->
      map = Map.get(command, :TagSpan)
      map && Map.get(map, :tag) == "error" && Map.get(map, :value) == "true"
    end)
  end

  test "adds ip context" do
    conn(:get, "/")
    |> ScoutApm.TestPlugApp.call([])

    [%{BatchCommand: %{commands: commands}}] = ScoutApm.TestCollector.messages()

    assert Enum.any?(commands, fn(command) ->
      map = Map.get(command, :StartSpan)
      map && Map.get(map, :operation) ==  "Controller/PageController#index"
    end)
    assert Enum.any?(commands, fn(command) ->
      map = Map.get(command, :TagRequest)
      map && Map.get(map, :tag) == :ip && is_binary(Map.get(map, :value))
    end)
  end

  test "adds ip context from x-forwarded-for header" do
    conn(:get, "/x-forwarded-for")
    |> ScoutApm.TestPlugApp.call([])

    [%{BatchCommand: %{commands: commands}}] = ScoutApm.TestCollector.messages()

    assert Enum.any?(commands, fn(command) ->
      map = Map.get(command, :StartSpan)
      map && Map.get(map, :operation) ==  "Controller/PageController#x-forwarded-for"
    end)
    assert Enum.any?(commands, fn(command) ->
      map = Map.get(command, :TagRequest)
      map && Map.get(map, :tag) == :ip && Map.get(map, :value) == "1.2.3.4"
    end)
  end

  test "does not create web trace when calling ScoutApm.TrackedRequest.ignore/0" do
    %{reporting_periods: periods} = ScoutApm.Store.get()
    data = case periods do
      [] ->
        %{}
      [pid] ->
        Agent.get(pid, fn(%{web_traces: %{data: data}}) ->
          data
        end)
    end

    conn(:get, "/?ignore=true")
    |> ScoutApm.TestPlugApp.call([])

    Application.delete_env(:scout_apm, :ignore_controller_transaction_function)

    :timer.sleep(100)

    %{reporting_periods: periods} = ScoutApm.Store.get()
    new_data = case periods do
      [] ->
        %{}
      [pid] ->
        Agent.get(pid, fn(%{web_traces: %{data: data}}) ->
          data
        end)
    end

    assert data == new_data
  end
end
