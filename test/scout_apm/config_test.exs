defmodule ScoutApm.ConfigTest do
  use ExUnit.Case, async: true

  test "find/1 with plain value" do
    Mix.Config.persist(scout_apm: [key: "abc123"])

    key = ScoutApm.Config.find(:key)

    assert key == "abc123"
  end

  test "find/1 with ENV variable" do
    System.put_env("SCOUT_API_KEY", "xyz123")
    Mix.Config.persist(scout_apm: [key: {:system, "SCOUT_API_KEY"}])

    key = ScoutApm.Config.find(:key)
    System.delete_env("SCOUT_API_KEY")

    assert key == "xyz123"
  end
end
