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
