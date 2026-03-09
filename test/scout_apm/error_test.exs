defmodule ScoutApm.ErrorTest do
  use ExUnit.Case

  describe "capture/2" do
    test "captures an exception and returns :ok" do
      exception = %RuntimeError{message: "test error"}

      assert ScoutApm.Error.capture(exception) == :ok
    end

    test "captures with stacktrace" do
      try do
        raise RuntimeError, "test"
      rescue
        e ->
          assert ScoutApm.Error.capture(e, stacktrace: __STACKTRACE__) == :ok
      end
    end

    test "captures with additional context" do
      exception = %RuntimeError{message: "test"}

      result =
        ScoutApm.Error.capture(exception,
          context: %{user_id: 123},
          request_path: "/api/users",
          request_params: %{"action" => "create"}
        )

      assert result == :ok
    end

    test "captures with custom controller" do
      exception = %RuntimeError{message: "test"}

      result =
        ScoutApm.Error.capture(exception,
          custom_controller: "UserController#show"
        )

      assert result == :ok
    end

    test "captures with custom params" do
      exception = %RuntimeError{message: "test"}

      result =
        ScoutApm.Error.capture(exception,
          custom_params: %{extra: "data"}
        )

      assert result == :ok
    end
  end

  describe "capture_from_telemetry/4" do
    test "captures error kind with exception" do
      exception = %ArgumentError{message: "bad arg"}
      stacktrace = [{__MODULE__, :test, 0, [file: ~c"test.ex", line: 1]}]

      assert ScoutApm.Error.capture_from_telemetry(:error, exception, stacktrace) == :ok
    end

    test "captures error kind with non-exception" do
      stacktrace = [{__MODULE__, :test, 0, [file: ~c"test.ex", line: 1]}]

      assert ScoutApm.Error.capture_from_telemetry(:error, :badarg, stacktrace) == :ok
    end

    test "captures throw kind" do
      stacktrace = [{__MODULE__, :test, 0, [file: ~c"test.ex", line: 1]}]

      assert ScoutApm.Error.capture_from_telemetry(:throw, "thrown", stacktrace) == :ok
    end

    test "captures exit kind" do
      stacktrace = [{__MODULE__, :test, 0, [file: ~c"test.ex", line: 1]}]

      assert ScoutApm.Error.capture_from_telemetry(:exit, :normal, stacktrace) == :ok
    end

    test "captures with options" do
      exception = %RuntimeError{message: "test"}
      stacktrace = [{__MODULE__, :test, 0, [file: ~c"test.ex", line: 1]}]

      result =
        ScoutApm.Error.capture_from_telemetry(:error, exception, stacktrace,
          request_path: "/test",
          custom_controller: "TestController"
        )

      assert result == :ok
    end
  end

  describe "enabled?/0" do
    test "returns true when errors are enabled" do
      # Default config has errors_enabled: true
      assert ScoutApm.Error.enabled?() == true
    end
  end
end
