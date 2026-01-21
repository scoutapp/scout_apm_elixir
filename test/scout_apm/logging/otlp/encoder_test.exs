defmodule ScoutApm.Logging.OTLP.EncoderTest do
  use ExUnit.Case

  alias ScoutApm.Logging.OTLP.Encoder
  alias ScoutApm.Logging.LogRecord

  describe "encode/1" do
    test "encodes a list of log records" do
      record = LogRecord.new(:info, "Test message", %{"key" => "value"})
      result = Encoder.encode([record])

      assert is_map(result)
      assert Map.has_key?(result, "resourceLogs")

      [resource_log] = result["resourceLogs"]
      assert Map.has_key?(resource_log, "resource")
      assert Map.has_key?(resource_log, "scopeLogs")

      [scope_log] = resource_log["scopeLogs"]
      assert Map.has_key?(scope_log, "scope")
      assert Map.has_key?(scope_log, "logRecords")

      [log_record] = scope_log["logRecords"]
      assert log_record["severityText"] == "INFO"
      assert log_record["severityNumber"] == 9
      assert log_record["body"]["stringValue"] == "Test message"
    end

    test "encodes empty list" do
      result = Encoder.encode([])

      [resource_log] = result["resourceLogs"]
      [scope_log] = resource_log["scopeLogs"]
      assert scope_log["logRecords"] == []
    end
  end

  describe "encode_log_record/1" do
    test "encodes basic log record" do
      record = LogRecord.new(:warning, "Warning message")
      result = Encoder.encode_log_record(record)

      assert result["severityText"] == "WARN"
      assert result["severityNumber"] == 13
      assert result["body"]["stringValue"] == "Warning message"
      assert is_binary(result["timeUnixNano"])
      assert is_binary(result["observedTimeUnixNano"])
    end

    test "encodes attributes" do
      record = LogRecord.new(:info, "Test", %{"string_key" => "value", "int_key" => 42})
      result = Encoder.encode_log_record(record)

      assert Map.has_key?(result, "attributes")
      attrs = result["attributes"]

      string_attr = Enum.find(attrs, &(&1["key"] == "string_key"))
      assert string_attr["value"]["stringValue"] == "value"

      int_attr = Enum.find(attrs, &(&1["key"] == "int_key"))
      assert int_attr["value"]["intValue"] == "42"
    end

    test "encodes boolean attributes" do
      record = LogRecord.new(:info, "Test", %{"bool_key" => true})
      result = Encoder.encode_log_record(record)

      attrs = result["attributes"]
      bool_attr = Enum.find(attrs, &(&1["key"] == "bool_key"))
      assert bool_attr["value"]["boolValue"] == true
    end

    test "encodes float attributes" do
      record = LogRecord.new(:info, "Test", %{"float_key" => 3.14})
      result = Encoder.encode_log_record(record)

      attrs = result["attributes"]
      float_attr = Enum.find(attrs, &(&1["key"] == "float_key"))
      assert float_attr["value"]["doubleValue"] == 3.14
    end

    test "does not include empty attributes" do
      record = LogRecord.new(:info, "Test", %{})
      result = Encoder.encode_log_record(record)

      refute Map.has_key?(result, "attributes")
    end

    test "does not include dropped count when zero" do
      record = LogRecord.new(:info, "Test")
      result = Encoder.encode_log_record(record)

      refute Map.has_key?(result, "droppedAttributesCount")
    end
  end
end
