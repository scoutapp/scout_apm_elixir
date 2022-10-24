defmodule ScoutApm.CacheTest do
  use ExUnit.Case

  ##############
  #  Hostname  #
  ##############

  test "stores hostname" do
    assert is_binary(ScoutApm.Cache.hostname())
  end

  #############
  #  Git SHA  #
  #############

  test "determines git sha from Heroku ENV" do
    System.put_env("HEROKU_SLUG_COMMIT", "abcd")
    assert ScoutApm.Cache.determine_git_sha() == "abcd"
    System.delete_env("HEROKU_SLUG_COMMIT")
  end

  test "determines git sha from SCOUT_REVISION_SHA env" do
    System.put_env("SCOUT_REVISION_SHA", "1234")
    assert ScoutApm.Cache.determine_git_sha() == "1234"
    System.delete_env("SCOUT_REVISION_SHA")
  end

  test "determines git sha from revision_sha application setting" do
    Application.put_all_env(scout_apm: [revision_sha: "abc123"])
    assert ScoutApm.Cache.determine_git_sha() == "abc123"
    Application.delete_env(:scout_apm, :revision_sha)
  end
end
