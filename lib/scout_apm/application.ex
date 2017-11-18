defmodule ScoutApm.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    DeferredConfig.populate(:scout_apm)

    children = [
      worker(ScoutApm.Store, []),
      worker(ScoutApm.Config, []),
      worker(ScoutApm.PersistentHistogram, []),
      worker(ScoutApm.Logger, []),

      worker(ScoutApm.ApplicationLoadNotification, [], [restart: :temporary]),

      worker(ScoutApm.Watcher, [ScoutApm.Store], id: :store_watcher),
      worker(ScoutApm.Watcher, [ScoutApm.Config], id: :config_watcher),
      worker(ScoutApm.Watcher, [ScoutApm.PersistentHistogram], id: :histogram_watcher),
      worker(ScoutApm.Watcher, [ScoutApm.Logger], id: :logger_watcher),
    ]

    # Stupidly persistent. Really high max restarts for debugging
    # opts = [strategy: :one_for_all, max_restarts: 10000000, max_seconds: 1, name: ScoutApm.Supervisor]
    opts = [strategy: :one_for_all, name: ScoutApm.Supervisor]
    {:ok, pid} = Supervisor.start_link(children, opts)

    ScoutApm.Watcher.start_link(ScoutApm.Supervisor)

    ScoutApm.Logger.reconfigure_from_config()
    ScoutApm.Logger.info("ScoutAPM Started")
    {:ok, pid}
  end
end
