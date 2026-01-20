defmodule ScoutApm.Application do
  @moduledoc false

  use Application

  @config_keys [
    :name,
    :key,
    :hostname,
    :monitor,
    :log_level,
    :core_agent_launch,
    :core_agent_download,
    :core_agent_dir,
    :core_agent_version,
    :core_agent_tcp_ip,
    :core_agent_tcp_port,
    :core_agent_log_level,
    :core_agent_log_file,
    :core_agent_config_file,
    :errors_enabled,
    :errors_host
  ]

  def start(_type, _args) do
    collector_module = ScoutApm.Config.find(:collector_module)

    children = [
      ScoutApm.PersistentHistogram,
      Supervisor.child_spec({ScoutApm.Watcher, ScoutApm.PersistentHistogram},
        id: :histogram_watcher
      ),
      collector_module,
      ScoutApm.Error.ErrorService
    ]

    ScoutApm.Cache.setup()

    # Stupidly persistent. Really high max restarts for debugging
    # opts = [strategy: :one_for_all, max_restarts: 10000000, max_seconds: 1, name: ScoutApm.Supervisor]
    opts = [strategy: :one_for_all, name: ScoutApm.Supervisor]
    {:ok, pid} = Supervisor.start_link(children, opts)

    ScoutApm.Watcher.start_link(ScoutApm.Supervisor)

    log_config()
    ScoutApm.Logger.log(:info, "ScoutAPM Started")
    {:ok, pid}
  end

  defp log_config do
    config_values =
      @config_keys
      |> Enum.map(fn key -> {key, ScoutApm.Config.find(key)} end)
      |> Enum.map(fn {key, value} -> "  #{key}: #{inspect(value)}" end)
      |> Enum.join("\n")

    ScoutApm.Logger.log(:debug, "ScoutAPM Configuration:\n#{config_values}")
  end
end
