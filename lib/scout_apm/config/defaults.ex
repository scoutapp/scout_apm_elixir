defmodule ScoutApm.Config.Defaults do
  def load do
    %{
      host: "https://checkin.scoutapm.com",
      direct_host: "https://apm.scoutapp.com",
      dev_trace: false,
      log_level: :info,
      monitor: true,
      ignore: [],
      core_agent_dir: "/tmp/scout_apm_core",
      core_agent_download: true,
      core_agent_launch: true,
      core_agent_version: "v1.5.1",
      core_agent_tcp_ip: {127, 0, 0, 1},
      core_agent_tcp_port: 9000,
      collector_module: ScoutApm.Core.AgentManager,
      download_url:
        "https://s3-us-west-1.amazonaws.com/scout-public-downloads/apm_core_agent/release",
      # Error tracking configuration
      errors_enabled: true,
      errors_host: "https://errors.scoutapm.com",
      errors_batch_size: 5,
      errors_max_queue_size: 500,
      errors_flush_interval_ms: 1_000,
      errors_ignored_exceptions: [],
      errors_filter_parameters: [],
      # OTLP Logging configuration
      logs_enabled: false,
      logs_endpoint: "https://otlp.scoutotel.com:4318",
      logs_ingest_key: nil,
      logs_batch_size: 100,
      logs_max_queue_size: 5000,
      logs_flush_interval_ms: 5_000,
      logs_level: :info,
      logs_filter_modules: []
    }
  end

  def contains?(data, key) do
    data[key] != nil
  end

  def lookup(data, key) do
    data[key]
  end
end
