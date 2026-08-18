defmodule ScoutApm.Core.AgentManagerDownloadTest do
  use ExUnit.Case

  alias ScoutApm.Core.AgentManager

  # These tests exercise the real HTTP download path against a local server.
  # They guard the hackney API usage in AgentManager.download_binary/3, which
  # must work on both the hackney 1.x and 4.x lines (see issue #141).

  setup do
    bypass = Bypass.open()

    dir =
      Path.join(
        System.tmp_dir!(),
        "scout_apm_download_test_#{System.unique_integer([:positive])}"
      )

    on_exit(fn -> File.rm_rf(dir) end)

    {:ok, bypass: bypass, dir: dir}
  end

  # Builds a gzipped tarball (in-memory bytes) containing a fake core-agent
  # binary, mirroring the layout of the real core agent release tarballs.
  defp tgz_fixture do
    tmp = Path.join(System.tmp_dir!(), "fixture_#{System.unique_integer([:positive])}.tgz")

    :ok =
      :erl_tar.create(
        String.to_charlist(tmp),
        [{~c"core-agent", "#!/bin/sh\necho fake core agent\n"}],
        [:compressed]
      )

    bytes = File.read!(tmp)
    File.rm!(tmp)
    bytes
  end

  test "downloads and extracts a tarball", %{bypass: bypass, dir: dir} do
    tgz = tgz_fixture()

    Bypass.expect_once(bypass, "GET", "/core-agent.tgz", fn conn ->
      Plug.Conn.resp(conn, 200, tgz)
    end)

    url = "http://localhost:#{bypass.port}/core-agent.tgz"

    assert :ok = AgentManager.download_binary(url, dir, "core-agent.tgz")
    assert File.exists?(Path.join(dir, "core-agent"))
  end

  test "follows redirects", %{bypass: bypass, dir: dir} do
    tgz = tgz_fixture()

    Bypass.expect_once(bypass, "GET", "/redirect.tgz", fn conn ->
      conn
      |> Plug.Conn.put_resp_header(
        "location",
        "http://localhost:#{bypass.port}/real.tgz"
      )
      |> Plug.Conn.resp(302, "")
    end)

    Bypass.expect_once(bypass, "GET", "/real.tgz", fn conn ->
      Plug.Conn.resp(conn, 200, tgz)
    end)

    url = "http://localhost:#{bypass.port}/redirect.tgz"

    assert :ok = AgentManager.download_binary(url, dir, "core-agent.tgz")
    assert File.exists?(Path.join(dir, "core-agent"))
  end

  test "returns an error tuple on a non-200 response", %{bypass: bypass, dir: dir} do
    Bypass.expect_once(bypass, "GET", "/missing.tgz", fn conn ->
      Plug.Conn.resp(conn, 404, "not found")
    end)

    url = "http://localhost:#{bypass.port}/missing.tgz"

    assert {:error, :failed_to_download_and_extract} =
             AgentManager.download_binary(url, dir, "core-agent.tgz")
  end

  test "returns an error tuple when the server is unreachable", %{bypass: bypass, dir: dir} do
    Bypass.down(bypass)

    url = "http://localhost:#{bypass.port}/core-agent.tgz"

    assert {:error, :failed_to_download_and_extract} =
             AgentManager.download_binary(url, dir, "core-agent.tgz")
  end
end
