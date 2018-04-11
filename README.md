# Scout Elixir Performance Monitoring Agent

`scout_apm` monitors the performance of Elixir applications in production and provides an in-browser profiler during development. Metrics are
reported to [Scout](https://scoutapp.com), a hosted application monitoring service.

![screenshot](https://s3-us-west-1.amazonaws.com/scout-blog/elixir_screenshot.png)

## Monitoring Usage

1. Signup for a [free Scout account](https://scoutapp.com/info/pricing).
2. Follow our install instructions within the UI.

[See our docs](http://help.apm.scoutapp.com/#elixir-agent) for detailed information.

## DevTrace (Development Profiler) Usage

DevTrace, Scout's in-browser development profiler, may be used without signup.

![devtrace](http://help.apm.scoutapp.com/images/devtrace.png)

To use:

1. [Follow the same installation steps as monitoring](http://help.apm.scoutapp.com/#elixir-install), but skip downloading the config file.
2. In your `config/dev.exs` file, add:
```elixir
# config/dev.exs
config :scout_apm,
  dev_trace: true
```
3. Restart your app.
4. Refresh your browser window and look for the speed badge.

## Instrumentation

See [our docs](http://help.apm.scoutapp.com/#elixir-instrumented-libaries) for information on libraries we auto-instrument (like Phoenix controller-actions) and guides for instrumenting Phoenix channels, Task, HTTPoison, GenServer, and more.
