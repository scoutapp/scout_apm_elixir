import Config

config :logger, backends: []

config :scout_apm,
  collector_module: ScoutApm.TestCollector
