# Testing Scout APM

Scout APM supports multiple Phoenix template engines through conditional compilation:
- **EEx** (`.eex`) - Standard Embedded Elixir templates
- **ExS** (`.exs`) - ExScript templates
- **HEEx** (`.heex`) - HTML-aware Embedded Elixir (Phoenix LiveView)

## Running Tests

```bash
mix deps.get
mix test
```

## Template Engine Tests

All template engine modules use conditional compilation via `Code.ensure_loaded?/1`:

```elixir
if Code.ensure_loaded?(Phoenix.LiveView.HTMLEngine) do
  defmodule ScoutApm.Instruments.HEExEngine do
    # ... only compiled when phoenix_live_view is available
  end
end
```

This means:
- Engines are only compiled when their dependencies are available
- Users only install the template engines they actually use
- No runtime errors for missing optional dependencies
- Scout APM "just works" with whatever template engines the user has installed

### Running Specific Template Engine Tests

```bash
# Test HEEx engine
mix test test/scout_apm/instruments/heex_engine_test.exs

# Test EEx engine
mix test test/scout_apm/instruments/eex_engine_test.exs

# Test ExS engine
mix test test/scout_apm/instruments/exs_engine_test.exs
```

## User Configuration

Users of Scout APM add template engines to their `config/config.exs`:

```elixir
config :phoenix, :template_engines,
  eex: ScoutApm.Instruments.EExEngine,
  exs: ScoutApm.Instruments.ExsEngine,
  heex: ScoutApm.Instruments.HEExEngine  # Only if phoenix_live_view is installed
```

The appropriate engines are automatically available based on the user's dependencies.

## CI

Tests run on GitHub Actions with the latest Elixir and OTP versions. See `.github/workflows/ci.yml` for configuration.
