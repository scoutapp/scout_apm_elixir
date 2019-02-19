use Mix.Config

config :logger, backends: []

config :scout_apm,
  collector_module: ScoutApm.TestCollector
