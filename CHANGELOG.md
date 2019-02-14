# master

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
