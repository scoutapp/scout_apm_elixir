defmodule ScoutApm.LoggingTest do
  use ExUnit.Case

  alias ScoutApm.Logging

  describe "attach/0 and detach/0" do
    test "attaches and detaches handler" do
      # Start fresh
      Logging.detach()
      refute Logging.attached?()

      # Attach
      assert Logging.attach() == :ok
      assert Logging.attached?()

      # Attaching again is idempotent
      assert Logging.attach() == :ok
      assert Logging.attached?()

      # Detach
      assert Logging.detach() == :ok
      refute Logging.attached?()

      # Detaching again is idempotent
      assert Logging.detach() == :ok
      refute Logging.attached?()
    end
  end

  describe "enabled?/0" do
    test "returns false by default" do
      # Default config has logs_enabled: false
      assert Logging.enabled?() == false
    end
  end

  describe "queue_size/0" do
    test "returns current queue size" do
      size = Logging.queue_size()
      assert is_integer(size)
      assert size >= 0
    end
  end

  describe "flush/0" do
    test "flushes without error" do
      assert Logging.flush() == :ok
    end
  end

  describe "drain/1" do
    test "drains without error" do
      assert Logging.drain(1000) == :ok
    end
  end
end
