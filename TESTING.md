# Testing Scout APM with Different Template Engines

Scout APM supports multiple Phoenix template engines through conditional compilation:
- **EEx** (`.eex`) - Standard Embedded Elixir templates
- **ExS** (`.exs`) - ExScript templates
- **HEEx** (`.heex`) - HTML-aware Embedded Elixir (Phoenix LiveView 0.17+)
- **Slime** (`.slim`, `.slime`) - Slim-like templates (optional, legacy)

## Template Engine Configuration

The test suite uses the `MIX_TEMPLATE_ENGINES` environment variable to control which optional template engine dependencies are installed:

### Modern Stack (Default)
Includes Phoenix LiveView and HEEx support:
```bash
mix deps.get
mix test
```

Or explicitly:
```bash
export MIX_TEMPLATE_ENGINES=modern
mix deps.get
mix test
```

**Dependencies:**
- Phoenix ~> 1.6
- phoenix_html ~> 3.0
- phoenix_live_view ~> 0.18

**Supported engines:** EEx, ExS, HEEx

### Legacy Stack
Includes Slime support (without LiveView):
```bash
export MIX_TEMPLATE_ENGINES=legacy
mix deps.get
mix test
```

**Dependencies:**
- Phoenix ~> 1.6
- phoenix_html ~> 2.14
- phoenix_slime ~> 0.9.0

**Supported engines:** EEx, ExS, Slime

**Note:** The slime package has known compatibility issues with newer Elixir versions (1.19+). The SlimeEngine module is maintained for users on older Elixir versions who still need Slime support.

## Running Specific Template Engine Tests

```bash
# Test HEEx engine (modern stack only)
mix test test/scout_apm/instruments/heex_engine_test.exs

# Test EEx engine (all configurations)
mix test test/scout_apm/instruments/eex_engine_test.exs

# Test ExS engine (all configurations)
mix test test/scout_apm/instruments/exs_engine_test.exs
```

## How It Works

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

## User Configuration

Users of Scout APM add template engines to their `config/config.exs`:

```elixir
config :phoenix, :template_engines,
  eex: ScoutApm.Instruments.EExEngine,
  exs: ScoutApm.Instruments.ExsEngine,
  heex: ScoutApm.Instruments.HEExEngine  # Only if phoenix_live_view is installed
```

The appropriate engines are automatically available based on the user's dependencies.
