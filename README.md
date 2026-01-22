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

## OTLP Logging

Scout APM can capture Elixir Logger messages, enrich them with request context, and send them to an OpenTelemetry collector via OTLP (OpenTelemetry Protocol).

### Setup

1. Enable logging in your configuration:

```elixir
# config/config.exs
config :scout_apm,
  logs_enabled: true,
  logs_ingest_key: "your-logs-ingest-key"  # Or falls back to :key
```

2. Attach the log handler in your application startup:

```elixir
# In your application.ex start/2
def start(_type, _args) do
  ScoutApm.Logging.attach()
  # ... rest of supervision tree
end
```

### Automatic Context Enrichment

Logs captured within Scout-tracked requests are automatically enriched with:

- `scout.request_id` - Unique request identifier for correlation
- `scout.transaction_name` - e.g., "Controller/UsersController#show"
- `scout.layer_type` - Current operation type (Controller, Ecto, etc.)
- `scout.layer_name` - Current operation name
- `scout.has_error` - Whether the request has encountered an error
- `scout.tag.{key}` - Custom tags from `ScoutApm.Context.add/2`
- `scout.user.{key}` - User context from `ScoutApm.Context.add_user/2`
- `service.name` - Application name from config

Example - logs are automatically enriched when inside a Scout-tracked request:

```elixir
def show(conn, %{"id" => id}) do
  user = Repo.get!(User, id)
  Logger.info("Fetched user", user_id: id)  # Includes Scout context automatically
  render(conn, :show, user: user)
end
```

### Custom Context

Add custom context that appears in your logs:

```elixir
ScoutApm.Context.add("feature_flag", "new_checkout")
ScoutApm.Context.add_user("id", current_user.id)

Logger.info("Processing checkout")  # Includes scout.tag.feature_flag and scout.user.id
```

### Configuration

```elixir
config :scout_apm,
  # Enable/disable log capture (default: false, opt-in)
  logs_enabled: true,

  # OTLP collector endpoint
  logs_endpoint: "https://otlp.scoutotel.com:4318",

  # Authentication key (falls back to :key if not set)
  logs_ingest_key: "your-logs-key",

  # Minimum log level to capture (default: :info)
  logs_level: :info,

  # Batching settings
  logs_batch_size: 100,           # Logs per batch (default: 100)
  logs_max_queue_size: 5000,      # Max queued logs (default: 5000)
  logs_flush_interval_ms: 5_000,  # Flush interval in ms (default: 5000)

  # Modules to exclude from capture (default: [])
  logs_filter_modules: [MyApp.VerboseModule]
```

### Programmatic Control

```elixir
# Attach with custom options
ScoutApm.Logging.attach(level: :warning, filter_modules: [MyApp.Noisy])

# Check if attached
ScoutApm.Logging.attached?()  # => true

# Force flush queued logs
ScoutApm.Logging.flush()

# Wait for queue to drain (useful for graceful shutdown)
ScoutApm.Logging.drain(5_000)

# Detach the handler
ScoutApm.Logging.detach()
```

### Log Levels

The following Elixir log levels are mapped to OTLP severity:

| Elixir Level | OTLP Severity | OTLP Number |
|--------------|---------------|-------------|
| `:debug`     | DEBUG         | 5           |
| `:info`      | INFO          | 9           |
| `:notice`    | INFO2         | 11          |
| `:warning`   | WARN          | 13          |
| `:error`     | ERROR         | 17          |
| `:critical`  | FATAL         | 21          |
| `:alert`     | FATAL         | 21          |
| `:emergency` | FATAL         | 21          |

## Development

See [TESTING.md](TESTING.md) for information on testing with different template engine configurations.
