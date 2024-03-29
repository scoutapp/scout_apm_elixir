defmodule ScoutApm.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    collector_module = ScoutApm.Config.find(:collector_module)

    children = [
      ScoutApm.PersistentHistogram,
      Supervisor.child_spec({ScoutApm.Watcher, ScoutApm.PersistentHistogram}, id: :histogram_watcher),
      collector_module
    ]

    ScoutApm.Cache.setup()

    # Stupidly persistent. Really high max restarts for debugging
    # opts = [strategy: :one_for_all, max_restarts: 10000000, max_seconds: 1, name: ScoutApm.Supervisor]
    opts = [strategy: :one_for_all, name: ScoutApm.Supervisor]
    {:ok, pid} = Supervisor.start_link(children, opts)

    ScoutApm.Watcher.start_link(ScoutApm.Supervisor)

    ScoutApm.Logger.log(:info, "ScoutAPM Started")
    {:ok, pid}
  end
end
