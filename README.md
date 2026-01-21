# Scout Elixir Performance Monitoring Agent

`scout_apm` monitors the performance of Elixir applications in production and provides an in-browser profiler during development. Metrics are
reported to [Scout](https://scoutapm.com), a hosted application monitoring service.

![screenshot](https://s3-us-west-1.amazonaws.com/scout-blog/elixir_screenshot.png)

## Monitoring Usage

1. Signup for a [free Scout account](https://scoutapp.com/info/pricing).
2. Follow our install instructions within the UI.

[See our docs](http://docs.scoutapm.com/#elixir-agent) for detailed information.

## DevTrace (Development Profiler) Usage

DevTrace, Scout's in-browser development profiler, may be used without signup.

![devtrace](http://docs.scoutapm.com/images/devtrace.png)

To use:

1. [Follow the same installation steps as monitoring](http://docs.scoutapm.com/#elixir-install), but skip downloading the config file.
2. In your `config/dev.exs` file, add:
```elixir
# config/dev.exs
config :scout_apm,
  dev_trace: true
```
3. Restart your app.
4. Refresh your browser window and look for the speed badge.

## Instrumentation

See [our docs](http://docs.scoutapm.com/#elixir-instrumented-libaries) for information on libraries we auto-instrument (like Phoenix controller-actions) and guides for instrumenting Phoenix channels, Task, HTTPoison, GenServer, and more.

### Supported Template Engines

Scout APM automatically instruments the following Phoenix template engines:

- **EEx** (`.eex`) - Standard Embedded Elixir templates
- **ExS** (`.exs`) - ExScript templates
- **HEEx** (`.heex`) - HTML-aware Embedded Elixir (requires `phoenix_live_view ~> 0.17`)
- **Slime** (`.slim`, `.slime`) - Slim-like templates (requires `phoenix_slime`)

Template engines are enabled automatically based on your project's dependencies. To use Scout's instrumented engines, add to your `config/config.exs`:

```elixir
config :phoenix, :template_engines,
  eex: ScoutApm.Instruments.EExEngine,
  exs: ScoutApm.Instruments.ExsEngine,
  heex: ScoutApm.Instruments.HEExEngine  # Only if phoenix_live_view is installed
```

## Error Tracking

Scout APM captures errors automatically and allows manual error capture.

### Automatic Error Capture

Errors are automatically captured from:
- Phoenix controller exceptions (via telemetry)
- LiveView exceptions (mount, handle_event, handle_params)
- Oban job failures
- Code wrapped in `transaction` blocks

To enable Phoenix router-level error capture, add to your application startup:

```elixir
# In your application.ex start/2
def start(_type, _args) do
  ScoutApm.Instruments.PhoenixErrorTelemetry.attach()
  # ... rest of supervision tree
end
```

### Manual Error Capture

Capture errors manually with `ScoutApm.Error.capture/2`:

```elixir
try do
  risky_operation()
rescue
  e ->
    ScoutApm.Error.capture(e, stacktrace: __STACKTRACE__)
    reraise e, __STACKTRACE__
end
```

With additional context:

```elixir
ScoutApm.Error.capture(exception,
  stacktrace: __STACKTRACE__,
  context: %{user_id: user.id},
  request_path: conn.request_path,
  request_params: conn.params
)
```

### Configuration

```elixir
config :scout_apm,
  # Enable/disable error capture (default: true)
  errors_enabled: true,

  # Exceptions to ignore (default: [])
  errors_ignored_exceptions: [Phoenix.Router.NoRouteError],

  # Additional parameter keys to filter (default: [])
  # Built-in: password, token, secret, api_key, auth, credentials, etc.
  errors_filter_parameters: ["credit_card", "cvv"]
```

## Development

See [TESTING.md](TESTING.md) for information on testing with different template engine configurations.
