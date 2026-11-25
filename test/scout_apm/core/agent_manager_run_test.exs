defmodule ScoutApm.Core.AgentManagerRunTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  alias ScoutApm.Core.AgentManager

  @env_keys [:monitor, :key, :core_agent_dir, :core_agent_tcp_port]

  setup do
    dir =
      Path.join(
        System.tmp_dir!(),
        "scout_apm_run_test_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)

    previous = for key <- @env_keys, do: {key, Application.fetch_env(:scout_apm, key)}

    # ScoutApm.Logger only logs when monitoring is enabled with a key. Point the
    # socket at an empty dir and TCP at a closed port so the connection fails.
    Application.put_env(:scout_apm, :monitor, true)
    Application.put_env(:scout_apm, :key, "abc123")
    Application.put_env(:scout_apm, :core_agent_dir, dir)
    Application.put_env(:scout_apm, :core_agent_tcp_port, closed_port())

    on_exit(fn ->
      for {key, value} <- previous do
        case value do
          {:ok, v} -> Application.put_env(:scout_apm, key, v)
          :error -> Application.delete_env(:scout_apm, key)
        end
      end

      File.rm_rf(dir)
    end)

    {:ok, dir: dir}
  end

  test "logs the Core Agent's output when it fails to start", %{dir: dir} do
    # Mimics a Core Agent binary the dynamic loader refuses to run.
    bin =
      fake_core_agent(dir, """
      echo "core-agent: /lib/x86_64-linux-gnu/libc.so.6: version \\`GLIBC_2.38' not found" >&2
      exit 1
      """)

    log = capture_log(fn -> assert AgentManager.run(bin) == nil end)

    assert log =~
             "ScoutApm Core Agent output: core-agent: /lib/x86_64-linux-gnu/libc.so.6: version `GLIBC_2.38' not found"

    assert log =~ "Unable to connect to ScoutApm Core Agent"
  end

  test "does not log an output line when the Core Agent printed nothing", %{dir: dir} do
    bin = fake_core_agent(dir, "exit 1\n")

    log = capture_log(fn -> assert AgentManager.run(bin) == nil end)

    refute log =~ "ScoutApm Core Agent output"
    assert log =~ "Unable to connect to ScoutApm Core Agent"
  end

  defp fake_core_agent(dir, body) do
    bin = Path.join(dir, "core-agent")
    File.write!(bin, "#!/bin/sh\n" <> body)
    File.chmod!(bin, 0o755)
    bin
  end

  # A port nothing is listening on: bind an ephemeral port, then release it.
  defp closed_port do
    {:ok, socket} = :gen_tcp.listen(0, [])
    {:ok, port} = :inet.port(socket)
    :ok = :gen_tcp.close(socket)
    port
  end
end
