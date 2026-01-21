defmodule ScoutApm.Logging.OTLP.SeverityTest do
  use ExUnit.Case

  alias ScoutApm.Logging.OTLP.Severity

  describe "to_number/1" do
    test "maps debug to 5" do
      assert Severity.to_number(:debug) == 5
    end

    test "maps info to 9" do
      assert Severity.to_number(:info) == 9
    end

    test "maps notice to 11" do
      assert Severity.to_number(:notice) == 11
    end

    test "maps warning to 13" do
      assert Severity.to_number(:warning) == 13
    end

    test "maps warn to 13" do
      assert Severity.to_number(:warn) == 13
    end

    test "maps error to 17" do
      assert Severity.to_number(:error) == 17
    end

    test "maps critical to 21" do
      assert Severity.to_number(:critical) == 21
    end

    test "maps alert to 21" do
      assert Severity.to_number(:alert) == 21
    end

    test "maps emergency to 21" do
      assert Severity.to_number(:emergency) == 21
    end

    test "maps unknown to 0" do
      assert Severity.to_number(:unknown) == 0
    end
  end

  describe "to_text/1" do
    test "maps debug to DEBUG" do
      assert Severity.to_text(:debug) == "DEBUG"
    end

    test "maps info to INFO" do
      assert Severity.to_text(:info) == "INFO"
    end

    test "maps warning to WARN" do
      assert Severity.to_text(:warning) == "WARN"
    end

    test "maps error to ERROR" do
      assert Severity.to_text(:error) == "ERROR"
    end

    test "maps critical to FATAL" do
      assert Severity.to_text(:critical) == "FATAL"
    end

    test "maps unknown to UNSPECIFIED" do
      assert Severity.to_text(:unknown) == "UNSPECIFIED"
    end
  end

  describe "meets_level?/2" do
    test "error meets info level" do
      assert Severity.meets_level?(:error, :info) == true
    end

    test "debug does not meet info level" do
      assert Severity.meets_level?(:debug, :info) == false
    end

    test "info meets info level" do
      assert Severity.meets_level?(:info, :info) == true
    end

    test "warning meets debug level" do
      assert Severity.meets_level?(:warning, :debug) == true
    end
  end

  describe "levels/0" do
    test "returns all levels in order" do
      levels = Severity.levels()
      assert :emergency in levels
      assert :debug in levels
      assert length(levels) == 8
    end
  end
end
