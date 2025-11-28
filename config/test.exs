import Config

config :logger, :default_handler, false

config :scout_apm,
  collector_module: ScoutApm.TestCollector
