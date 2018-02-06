defmodule ScoutApm.ConfigTest do
  use ExUnit.Case, async: false

  test "find/1 with plain value" do
    Mix.Config.persist(scout_apm: [key: "abc123"])

    key = ScoutApm.Config.find(:key)

    assert key == "abc123"
    Application.delete_env(:scout_apm, :key)
  end

  test "find/1 with application defined ENV variable" do
    System.put_env("APM_API_KEY", "xyz123")
    Mix.Config.persist(scout_apm: [key: {:system, "APM_API_KEY"}])

    key = ScoutApm.Config.find(:key)
    System.delete_env("APM_API_KEY")

    assert key == "xyz123"
  end

  test "find/1 with SCOUT_* ENV variables" do
    System.put_env("SCOUT_KEY", "zxc")
    key = ScoutApm.Config.find(:key)
    assert key == "zxc"
    System.delete_env("SCOUT_KEY")
  end
end
