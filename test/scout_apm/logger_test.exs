defmodule ScoutApm.LoggerTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  test "always logs errors" do
    Mix.Config.persist(scout_apm: [monitor: true, key: "abc123"])

    Application.put_env(:scout_apm, :log_level, :debug)

    assert capture_log(fn ->
             ScoutApm.Logger.log(:error, "Debug Log")
           end) =~ "Debug Log"

    Application.put_env(:scout_apm, :log_level, :info)

    assert capture_log(fn ->
             ScoutApm.Logger.log(:error, "Info Log")
           end) =~ "Info Log"

    Application.put_env(:scout_apm, :log_level, :warn)

    assert capture_log(fn ->
             ScoutApm.Logger.log(:error, "Warn Log")
           end) =~ "Warn Log"

    Application.put_env(:scout_apm, :log_level, :error)

    assert capture_log(fn ->
             ScoutApm.Logger.log(:error, "Error Log")
           end) =~ "Error Log"

    Application.delete_env(:scout_apm, :monitor)
    Application.delete_env(:scout_apm, :log_level)
    Application.delete_env(:scout_apm, :key)
  end

  test "only logs debug in debug level" do
    Mix.Config.persist(scout_apm: [monitor: true, key: "abc123"])

    Application.put_env(:scout_apm, :log_level, :debug)

    assert capture_log(fn ->
             ScoutApm.Logger.log(:error, "Debug Log")
           end) =~ "Debug Log"

    Application.put_env(:scout_apm, :log_level, :info)

    assert capture_log(fn ->
             ScoutApm.Logger.log(:debug, "Info Log")
           end) == ""

    Application.put_env(:scout_apm, :log_level, :warn)

    assert capture_log(fn ->
             ScoutApm.Logger.log(:debug, "Warn Log")
           end) == ""

    Application.put_env(:scout_apm, :log_level, :error)

    assert capture_log(fn ->
             ScoutApm.Logger.log(:debug, "Error Log")
           end) == ""

    Application.delete_env(:scout_apm, :monitor)
    Application.delete_env(:scout_apm, :log_level)
    Application.delete_env(:scout_apm, :key)
  end

  test "never logs if key is not configured" do
    Mix.Config.persist(scout_apm: [monitor: true, key: nil, log_level: :debug])

    assert capture_log(fn ->
             ScoutApm.Logger.log(:error, "Log")
           end) == ""

    Application.delete_env(:scout_apm, :monitor)
    Application.delete_env(:scout_apm, :log_level)
  end
end
