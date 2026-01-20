defmodule ScoutApm.Error.ErrorServiceTest do
  use ExUnit.Case

  alias ScoutApm.Error.ErrorData
  alias ScoutApm.Error.ErrorService

  # The ErrorService is started by the application, so we don't need to start it here

  describe "send/1" do
    test "accepts error data and returns :ok" do
      error_data =
        ErrorData.from_exception(%RuntimeError{message: "test"}, stacktrace: [])

      assert ErrorService.send(error_data) == :ok
    end
  end

  describe "flush/0" do
    test "forces immediate flush and returns :ok" do
      assert ErrorService.flush() == :ok
    end
  end

  describe "drain/1" do
    test "waits for queue to drain and returns :ok" do
      # Send some errors
      for i <- 1..3 do
        error_data =
          ErrorData.from_exception(%RuntimeError{message: "test #{i}"}, stacktrace: [])

        ErrorService.send(error_data)
      end

      # Drain should complete
      assert ErrorService.drain(5000) == :ok
    end
  end
end
