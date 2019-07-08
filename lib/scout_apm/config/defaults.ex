defmodule ScoutApm.Config.Defaults do
  def load do
    %{
      host: "https://checkin.scoutapp.com",
      direct_host: "https://apm.scoutapp.com",
      dev_trace: false,
      monitor: true,
      ignore: [],
      core_agent_dir: "/tmp/scout_apm_core",
      core_agent_download: true,
      core_agent_launch: true,
      core_agent_version: "v1.1.8",
      core_agent_tcp_ip: {127, 0, 0, 1},
      core_agent_tcp_port: 9000,
      collector_module: ScoutApm.Core.AgentManager,
      download_url:
        "https://s3-us-west-1.amazonaws.com/scout-public-downloads/apm_core_agent/release"
    }
  end

  def contains?(data, key) do
    data[key] != nil
  end

  def lookup(data, key) do
    data[key]
  end
end
