defmodule ScoutApm.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    Logger.info("Starting ScoutAPM")
    children = [
      worker(ScoutApm.Store, []),
      worker(ScoutApm.Config, []),
      worker(ScoutApm.PersistentHistogram, []),
      # worker(ScoutApm.ApplicationLoadNotification, [restart: :transient])
      worker(ScoutApm.Watcher, [ScoutApm.Store], id: :store_watcher),
      worker(ScoutApm.Watcher, [ScoutApm.Config], id: :config_watcher),
      worker(ScoutApm.Watcher, [ScoutApm.PersistentHistogram], id: :histogram_watcher),
    ]

    # Stupidly persistent. Really high max restarts for debugging
    # opts = [strategy: :one_for_all, max_restarts: 10000000, max_seconds: 1, name: ScoutApm.Supervisor]
    opts = [strategy: :one_for_all, name: ScoutApm.Supervisor]
    {:ok, pid} = Supervisor.start_link(children, opts)

    ScoutApm.Watcher.start_link(ScoutApm.Supervisor)

    {:ok, pid}
  end
end
