defmodule ScoutApm.Plugs.ControllerTimerTest do
  use ExUnit.Case, async: false
  use Plug.Test

  test "creates web trace" do
    conn(:get, "/")
    |> ScoutApm.TestPlugApp.call([])

    :timer.sleep(50)
    %{reporting_periods: [pid]} = ScoutApm.Store.get()
    Agent.get(pid, fn(%{web_traces: %{data: data}}) ->
      assert Map.has_key?(data, "Controller/PageController#index")
    end)
  end

  test "includes error metric on 500 response" do
    conn(:get, "/500")
    |> ScoutApm.TestPlugApp.call([])

    :timer.sleep(50)
    %{reporting_periods: [pid]} = ScoutApm.Store.get()
    Agent.get(pid, fn(%{web_metric_set: %{data: data}}) ->
      assert Map.has_key?(data, "Errors/Controller/PageController#500/scope//")
    end)
  end

  test "adds ip context" do
    conn(:get, "/")
    |> ScoutApm.TestPlugApp.call([])

    :timer.sleep(50)
    %{reporting_periods: [pid]} = ScoutApm.Store.get()
    Agent.get(pid, fn(state) ->
      %{web_traces: %{data: %{"Controller/PageController#index" => {_, %{contexts: [context]}}}}} = state
      %{key: :ip, type: :user, value: value} = context
      assert is_binary(value)
    end)
  end

  test "adds ip context from x-forwarded-for header" do
    conn(:get, "/x-forwarded-for")
    |> ScoutApm.TestPlugApp.call([])

    :timer.sleep(100)
    %{reporting_periods: [pid]} = ScoutApm.Store.get()
    Agent.get(pid, fn(state) ->
      %{web_traces: %{data: %{"Controller/PageController#x-forwarded-for" => {_, %{contexts: [context]}}}}} = state
      assert context == %ScoutApm.Internal.Context{key: :ip, type: :user, value: "1.2.3.4"}
    end)
  end
end
