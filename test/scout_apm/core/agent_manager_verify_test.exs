defmodule ScoutApm.Core.AgentManagerVerifyTest do
  use ExUnit.Case

  alias ScoutApm.Core
  alias ScoutApm.Core.AgentManager

  # verify_or_download/0 must not keep reusing a Core Agent that an earlier
  # release downloaded for another version or platform triple (e.g. the glibc
  # build 2.2.0 put in the default /tmp/scout_apm_core).

  @env_keys [:core_agent_dir, :core_agent_download, :core_agent_triple, :download_url]

  setup do
    bypass = Bypass.open()

    dir =
      Path.join(
        System.tmp_dir!(),
        "scout_apm_verify_test_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)

    previous = for key <- @env_keys, do: {key, Application.fetch_env(:scout_apm, key)}

    Application.put_env(:scout_apm, :core_agent_dir, dir)
    Application.put_env(:scout_apm, :core_agent_download, true)
    Application.put_env(:scout_apm, :core_agent_triple, "x86_64-unknown-linux-musl")
    Application.put_env(:scout_apm, :download_url, "http://localhost:#{bypass.port}")

    on_exit(fn ->
      for {key, value} <- previous do
        case value do
          {:ok, v} -> Application.put_env(:scout_apm, key, v)
          :error -> Application.delete_env(:scout_apm, key)
        end
      end

      File.rm_rf(dir)
    end)

    {:ok, bypass: bypass, dir: dir}
  end

  test "downloads the current agent when the directory holds another build",
       %{bypass: bypass, dir: dir} do
    seed_agent(dir, "gnu build", "scout_apm_core-v1.6.0-x86_64-unknown-linux-gnu.tgz")
    tgz = agent_tgz("musl build")

    Bypass.expect_once(bypass, "GET", "/#{Core.agent_full_name()}.tgz", fn conn ->
      Plug.Conn.resp(conn, 200, tgz)
    end)

    assert {:ok, manifest} = AgentManager.verify_or_download()
    assert File.read!(Core.Manifest.bin_path(manifest)) == "musl build"
  end

  test "keeps the existing agent when the download fails", %{bypass: bypass, dir: dir} do
    seed_agent(dir, "gnu build", "scout_apm_core-v1.6.0-x86_64-unknown-linux-gnu.tgz")

    Bypass.expect_once(bypass, "GET", "/#{Core.agent_full_name()}.tgz", fn conn ->
      Plug.Conn.resp(conn, 404, "not found")
    end)

    assert {:ok, manifest} = AgentManager.verify_or_download()
    assert File.read!(Core.Manifest.bin_path(manifest)) == "gnu build"
  end

  test "retries the replacement on the next start when extraction fails",
       %{bypass: bypass, dir: dir} do
    seed_agent(dir, "gnu build", "scout_apm_core-v1.6.0-x86_64-unknown-linux-gnu.tgz")
    path = "/#{Core.agent_full_name()}.tgz"

    Bypass.expect_once(bypass, "GET", path, fn conn ->
      Plug.Conn.resp(conn, 200, "not a tarball")
    end)

    assert {:ok, manifest} = AgentManager.verify_or_download()
    assert File.read!(Core.Manifest.bin_path(manifest)) == "gnu build"
    refute File.exists?(Path.join(dir, "#{Core.agent_full_name()}.tgz"))

    tgz = agent_tgz("musl build")

    Bypass.expect_once(bypass, "GET", path, fn conn ->
      Plug.Conn.resp(conn, 200, tgz)
    end)

    assert {:ok, manifest} = AgentManager.verify_or_download()
    assert File.read!(Core.Manifest.bin_path(manifest)) == "musl build"
  end

  test "replaces an agent binary it can't write over", %{bypass: bypass, dir: dir} do
    # Stands in for a running Core Agent, which Linux won't let a write
    # replace (:etxtbsy). A rename replaces either.
    seed_agent(dir, "gnu build", "scout_apm_core-v1.6.0-x86_64-unknown-linux-gnu.tgz")
    File.chmod!(Path.join(dir, "core-agent"), 0o555)
    File.chmod!(Path.join(dir, "manifest.json"), 0o444)
    tgz = agent_tgz("musl build")

    Bypass.expect_once(bypass, "GET", "/#{Core.agent_full_name()}.tgz", fn conn ->
      Plug.Conn.resp(conn, 200, tgz)
    end)

    assert {:ok, manifest} = AgentManager.verify_or_download()
    assert File.read!(Core.Manifest.bin_path(manifest)) == "musl build"
    assert File.exists?(Path.join(dir, "#{Core.agent_full_name()}.tgz"))
    assert Enum.all?(File.ls!(dir), &(not String.starts_with?(&1, ".")))
  end

  test "reuses the agent when its tarball matches the current build", %{dir: dir} do
    seed_agent(dir, "musl build", "#{Core.agent_full_name()}.tgz")

    # No Bypass expectation: any request fails the test.
    assert {:ok, manifest} = AgentManager.verify_or_download()
    assert File.read!(Core.Manifest.bin_path(manifest)) == "musl build"
  end

  test "reuses a hand-placed agent when downloads are disabled", %{dir: dir} do
    Application.put_env(:scout_apm, :core_agent_download, false)
    seed_agent(dir, "hand placed", nil)

    assert {:ok, manifest} = AgentManager.verify_or_download()
    assert File.read!(Core.Manifest.bin_path(manifest)) == "hand placed"
  end

  defp manifest_json(content) do
    sha = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)

    Jason.encode!(%{
      "version" => "1.0",
      "core_agent_version" => "v1.6.0",
      "core_agent_binary" => "core-agent",
      "core_agent_binary_sha256" => sha
    })
  end

  defp seed_agent(dir, content, tgz_name) do
    File.write!(Path.join(dir, "core-agent"), content)
    File.write!(Path.join(dir, "manifest.json"), manifest_json(content))
    if tgz_name, do: File.write!(Path.join(dir, tgz_name), "old tarball")
  end

  defp agent_tgz(content) do
    tmp = Path.join(System.tmp_dir!(), "fixture_#{System.unique_integer([:positive])}.tgz")

    :ok =
      :erl_tar.create(
        String.to_charlist(tmp),
        [{~c"core-agent", content}, {~c"manifest.json", manifest_json(content)}],
        [:compressed]
      )

    bytes = File.read!(tmp)
    File.rm!(tmp)
    bytes
  end
end
