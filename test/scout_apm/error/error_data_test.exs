defmodule ScoutApm.Error.ErrorDataTest do
  use ExUnit.Case

  alias ScoutApm.Error.ErrorData

  describe "from_exception/2" do
    test "creates error data from an exception" do
      exception = %RuntimeError{message: "Something went wrong"}
      error_data = ErrorData.from_exception(exception)

      assert error_data.exception_class == "RuntimeError"
      assert error_data.message == "Something went wrong"
      assert is_binary(error_data.request_id)
      assert is_list(error_data.trace)
      assert error_data.host != nil
    end

    test "includes stacktrace when provided" do
      exception = %RuntimeError{message: "test"}

      try do
        raise exception
      rescue
        e ->
          error_data = ErrorData.from_exception(e, stacktrace: __STACKTRACE__)
          assert length(error_data.trace) > 0
          assert Enum.any?(error_data.trace, &String.contains?(&1, "error_data_test.exs"))
      end
    end

    test "includes request path when provided" do
      exception = %RuntimeError{message: "test"}
      error_data = ErrorData.from_exception(exception, request_path: "/api/users")

      assert error_data.request_uri == "/api/users"
    end

    test "filters request params" do
      exception = %RuntimeError{message: "test"}

      error_data =
        ErrorData.from_exception(exception,
          request_params: %{"password" => "secret", "name" => "john"}
        )

      assert error_data.request_params["password"] == "[FILTERED]"
      assert error_data.request_params["name"] == "john"
    end

    test "includes custom controller" do
      exception = %RuntimeError{message: "test"}
      error_data = ErrorData.from_exception(exception, custom_controller: "UserController#show")

      assert error_data.request_components["controller"] == "UserController#show"
    end

    test "includes user-provided context" do
      exception = %RuntimeError{message: "test"}
      error_data = ErrorData.from_exception(exception, context: %{user_id: 123})

      assert error_data.context[:user_id] == 123
    end

    test "includes custom params" do
      exception = %RuntimeError{message: "test"}
      error_data = ErrorData.from_exception(exception, custom_params: %{extra: "data"})

      assert error_data.context["custom_params"][:extra] == "data"
    end
  end

  describe "from_telemetry/4" do
    test "handles :error kind with exception" do
      exception = %ArgumentError{message: "invalid argument"}
      stacktrace = [{__MODULE__, :test, 0, [file: ~c"test.ex", line: 1]}]

      error_data = ErrorData.from_telemetry(:error, exception, stacktrace, [])

      assert error_data.exception_class == "ArgumentError"
      assert error_data.message == "invalid argument"
    end

    test "handles :error kind with non-exception reason" do
      stacktrace = [{__MODULE__, :test, 0, [file: ~c"test.ex", line: 1]}]

      error_data = ErrorData.from_telemetry(:error, {:badmatch, :something}, stacktrace, [])

      assert error_data.exception_class == "ErlangError"
      assert error_data.message =~ "badmatch"
    end

    test "handles :throw kind" do
      stacktrace = [{__MODULE__, :test, 0, [file: ~c"test.ex", line: 1]}]

      error_data = ErrorData.from_telemetry(:throw, "thrown value", stacktrace, [])

      assert error_data.exception_class == "ThrowError"
      assert error_data.message =~ "thrown value"
    end

    test "handles :exit kind" do
      stacktrace = [{__MODULE__, :test, 0, [file: ~c"test.ex", line: 1]}]

      error_data = ErrorData.from_telemetry(:exit, :normal, stacktrace, [])

      assert error_data.exception_class == "ExitError"
      assert error_data.message =~ "normal"
    end

    test "includes options" do
      exception = %RuntimeError{message: "test"}
      stacktrace = [{__MODULE__, :test, 0, [file: ~c"test.ex", line: 1]}]

      error_data =
        ErrorData.from_telemetry(:error, exception, stacktrace,
          request_path: "/test",
          custom_controller: "TestController"
        )

      assert error_data.request_uri == "/test"
      assert error_data.request_components["controller"] == "TestController"
    end
  end

  describe "to_map/1" do
    test "converts error data to a map" do
      exception = %RuntimeError{message: "test error"}
      error_data = ErrorData.from_exception(exception, request_path: "/test")

      map = ErrorData.to_map(error_data)

      assert map["exception_class"] == "RuntimeError"
      assert map["message"] == "test error"
      assert map["request_uri"] == "/test"
      assert is_list(map["trace"])
    end

    test "excludes nil values" do
      exception = %RuntimeError{message: "test"}
      error_data = ErrorData.from_exception(exception)

      map = ErrorData.to_map(error_data)

      # request_params should not be present if nil
      refute Map.has_key?(map, "request_params")
      refute Map.has_key?(map, "request_session")
      refute Map.has_key?(map, "environment")
    end
  end
end
