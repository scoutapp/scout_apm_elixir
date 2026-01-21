defmodule ScoutApm.Logging.LogRecordTest do
  use ExUnit.Case

  alias ScoutApm.Logging.LogRecord

  describe "new/3" do
    test "creates a log record with severity and message" do
      record = LogRecord.new(:info, "Test message")

      assert record.severity == :info
      assert record.message == "Test message"
      assert is_integer(record.timestamp_nanos)
      assert is_integer(record.observed_timestamp_nanos)
    end

    test "creates a log record with attributes" do
      record = LogRecord.new(:warning, "Warning", %{"key" => "value"})

      assert record.attributes == %{"key" => "value"}
    end

    test "truncates long messages" do
      long_message = String.duplicate("a", 40_000)
      record = LogRecord.new(:info, long_message)

      assert String.length(record.message) <= 32_768
      assert String.ends_with?(record.message, "...")
    end
  end

  describe "from_logger_event/2" do
    test "creates from string message event" do
      event = %{
        level: :info,
        msg: {:string, "Hello world"},
        meta: %{
          time: System.system_time(:microsecond),
          file: ~c"test.ex",
          line: 10
        }
      }

      record = LogRecord.from_logger_event(event)

      assert record.severity == :info
      assert record.message == "Hello world"
    end

    test "creates from binary string message" do
      event = %{
        level: :error,
        msg: {:string, "Binary message"},
        meta: %{time: System.system_time(:microsecond)}
      }

      record = LogRecord.from_logger_event(event)

      assert record.message == "Binary message"
    end

    test "creates from format message" do
      event = %{
        level: :debug,
        msg: {~c"User ~p logged in", [:john]},
        meta: %{time: System.system_time(:microsecond)}
      }

      record = LogRecord.from_logger_event(event)

      assert record.message == "User john logged in"
    end

    test "includes source location in attributes" do
      event = %{
        level: :info,
        msg: {:string, "test"},
        meta: %{
          time: System.system_time(:microsecond),
          file: ~c"lib/my_app.ex",
          line: 42,
          mfa: {MyApp.Module, :function, 2}
        }
      }

      record = LogRecord.from_logger_event(event)

      assert record.attributes["code.filepath"] == "lib/my_app.ex"
      assert record.attributes["code.lineno"] == 42
      assert record.attributes["code.function"] == "MyApp.Module.function/2"
    end

    test "includes scout context" do
      event = %{
        level: :info,
        msg: {:string, "test"},
        meta: %{time: System.system_time(:microsecond)}
      }

      scout_context = [
        {"scout.request_id", "req-123"},
        {"scout.transaction_name", "Controller/Users#show"}
      ]

      record = LogRecord.from_logger_event(event, scout_context)

      assert record.attributes["scout.request_id"] == "req-123"
      assert record.attributes["scout.transaction_name"] == "Controller/Users#show"
    end

    test "includes custom metadata" do
      event = %{
        level: :info,
        msg: {:string, "test"},
        meta: %{
          time: System.system_time(:microsecond),
          user_id: 123,
          request_id: "abc"
        }
      }

      record = LogRecord.from_logger_event(event)

      assert record.attributes["user_id"] == 123
      assert record.attributes["request_id"] == "abc"
    end

    test "filters internal metadata" do
      event = %{
        level: :info,
        msg: {:string, "test"},
        meta: %{
          time: System.system_time(:microsecond),
          gl: self(),
          pid: self(),
          domain: [:elixir],
          custom_key: "value"
        }
      }

      record = LogRecord.from_logger_event(event)

      refute Map.has_key?(record.attributes, "gl")
      refute Map.has_key?(record.attributes, "pid")
      refute Map.has_key?(record.attributes, "domain")
      assert record.attributes["custom_key"] == "value"
    end
  end
end
