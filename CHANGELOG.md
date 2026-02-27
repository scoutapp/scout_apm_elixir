# master

# 2.0.0

* New Features
  * Error Monitoring — Automatic capture of unhandled exceptions in Phoenix controllers via telemetry. Errors are reported to Scout with full stacktraces, request context, and filtered parameters. Configure with `errors_enabled`, `errors_ignored_exceptions`, and `errors_filter_parameters`.
  * Log Management — OTLP-based log forwarding to Scout. Integrates with Elixir's Logger via a custom handler. Supports batched delivery, severity mapping, and automatic context extraction. Configure with `logs_enabled`, `logs_endpoint`, `logs_ingest_key`, `logs_level`, and `logs_filter_modules`.
  * External Services (Finch) — Automatic instrumentation of outbound HTTP calls via Finch (and Req) using `:telemetry`. Captures method, URL, status code, and duration.
  * External Services (Tesla) — Automatic instrumentation of outbound HTTP calls via Tesla using `:telemetry`. Captures method, URL, status code, and duration.
  * LiveView Telemetry — Automatic instrumentation of Phoenix LiveView `mount`, `handle_event`, and `handle_params` callbacks.
  * Oban Telemetry — Automatic instrumentation of Oban background job execution. Jobs appear as `Job` type spans.
  * HEEx Engine — Template render instrumentation for `.heex` templates (Phoenix 1.6+).
  * Database Metrics — Ecto spans now include `db.command` and `db.rows` tags for richer database visibility.
  * Metadata Capture — Improved application metadata reporting including Elixir version, loaded libraries, hostname, and git SHA.

* Enhancements
  * Update Core Agent to v1.5.0 (from v1.2.6)
  * Update telemetry dependency to `~> 1.0` (from `~> 0.3.0 or ~> 0.4.0`)
  * Phoenix, phoenix_html, and phoenix_live_view are now optional dependencies (enables compile-time HEEx instrumentation)
  * Ecto logger extracts SQL command type and row counts from query results
  * Better core agent lifecycle handling (already-running detection, config file path support)
  * Default checkin host updated to `checkin.scoutapm.com`

* New Configuration Options
  * `errors_enabled` (default: `true`) — Enable/disable error capture
  * `errors_host` (default: `https://errors.scoutapm.com`) — Error reporting endpoint
  * `errors_batch_size` (default: `5`) — Errors per batch
  * `errors_max_queue_size` (default: `500`) — Max queued errors
  * `errors_flush_interval_ms` (default: `1000`) — Error flush interval
  * `errors_ignored_exceptions` (default: `[]`) — Exception modules to ignore
  * `errors_filter_parameters` (default: `[]`) — Parameter keys to redact
  * `logs_enabled` (default: `false`) — Enable/disable log forwarding
  * `logs_endpoint` (default: `https://otlp.scoutotel.com:4318`) — OTLP log endpoint
  * `logs_ingest_key` (default: `nil`) — Ingest API key for log forwarding
  * `logs_batch_size` (default: `100`) — Logs per batch
  * `logs_max_queue_size` (default: `5000`) — Max queued logs
  * `logs_flush_interval_ms` (default: `5000`) — Log flush interval
  * `logs_level` (default: `:info`) — Minimum log level to forward
  * `logs_filter_modules` (default: `[]`) — Logger modules to exclude
  * `log_level` (default: `:info`) — Scout agent's own log level

* Breaking Changes
  * Elixir >= 1.14 required (was 1.4)
  * Telemetry `~> 1.0` required (was `~> 0.3.0 or ~> 0.4.0`)
  * Phoenix `~> 1.6` (optional, was `~> 1.0`)
  * Removed `phoenix_slime` dependency
  * Removed `credo` dependency

# 1.0.7

* Enhancements
  * Add URI to request context (#114)

# 1.0.6

* Enhancements
  * Allow expanding app name in template metrics (#111)

# 1.0.5

* Enhancements
  * Update CoreAgent to 1.2.6 (#109)
  * Send Queue Time as String (#110)

# 1.0.4

* Enhancements
  * Queue time metric for Nginx (#106)

# 1.0.3

* Enhancements
  * Update Core Agent default version to v1.2.4 (#105)

# 1.0.2

* Bug Fixes
  * Send TrackedRequest error as a TagRequest (#104)
  * Ensure git\_sha is not nil (#104)

# 1.0.1

* Enhancements
  * Better core agent platform detection (#101)

* Bug Fixes
  * Do not try to start core agent or send messages with no key (#102)


# 1.0.0

* Enhancements
  * Send platform in metadata (#92)
  * Use Core Agent to gather and transmit metrics (#93)
  * Use Jason instead of Poison for JSON encoding (#96)
  * Add Mix task to check configuration (#97)
  * Queue time metric and renaming capability for transactions (#98)

* Bug Fixes
  * Fix error in converting list to string (#90)
  * Fix mismatched layers during ignored transaction(#95)

* Breaking Changes
  * Deprecated tracing `@transaction` and `@timing` module attributes have been removed

# 0.4.15

* Fix Ecto 2 support (#88)

# 0.4.14

* Support Telemetry 0.3.0/0.4.0 and Ecto 3.0/3.1 (#84)

# 0.4.13

* Support Instrumenting multiple Ecto repos (#81)

# 0.4.12

* Add ScoutApm.TrackedRequest.ignore() to immediately ignore and stop any
  additional data collection for the current Transaction.

# 0.4.11

* Fix Ecto Telemetry when Repo module is deeply nested.

# 0.4.10

* Fix deprecation warnings from newer Elixir versions

# 0.4.9

* Enhancements
  * Make `action_name` function public for use in instrumenting chunked HTTP responses (#70)

# 0.4.8

* Enhancements
  * Ecto 3 support

# 0.4.7

* Enhancements
  * Add Deploy Tracking
  * Attach Git SHA to Traces

# 0.4.6

* Bug Fixes
  * Fix cache start order (#64)

# 0.4.5

* Bug Fixes
  * Set hostname on slow transactions (#61)
  * Avoid raising on layer mismatch (#63)

# 0.4.4

* Bug Fixes
  * Do not raise when Ecto.LogEntry has nil query\_time (#58)

# 0.4.3

* Enhancements
  * Track Error Rates (#56)
* Bug Fixes
  * Fix compile warning if project is not using PhoenixSlime (#56)

# 0.4.2

* Enhancements
  * Added ability to instrument Slime templates (#54)

# 0.4.1

* Enhancements
  * Added `deftiming` and `deftransaction` macros to ScoutApm.Tracing (#52)
  * Rename DevTrace.Store to DirectAnalysisStore and always enable (#51)

# 0.4.0
* Enhancements
  * Silence logging when Scout is not configured (#46)
  * Allow configuration of ignored routes (#45)
  * Remove Configuration module GenServer (#47)
* Bug Fixes
  * Prevent error when popping element from a TrackedRequest (#44)

# 0.3.3

* Fix bug serializing histograms in certain cases

# 0.3.0

* Added ability to instrument background job transactions
* Added instrumentation via module attributes
* Added instrumentation via `transaction/4` and `timing/4` macros
* Deprecated `instrument/4`
* Wrapped `transaction/4` and `timing/4` inside `try` blocks so an exception in instrumented code still tracks the associated transaction / timing.
