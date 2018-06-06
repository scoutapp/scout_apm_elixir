defmodule ScoutApm.CacheTest do
  use ExUnit.Case

  test "stores hostname" do
    assert is_binary(ScoutApm.Cache.hostname())
  end
end
