# 0.3.0

* Added ability to instrument background job transactions
* Added instrumentation via module attributes
* Added instrumentation via `transaction/4` and `timing/4` macros
* Deprecated `instrument/4`
* Wrapped `transaction/4` and `timing/4` inside `try` blocks so an exception in instrumented code still tracks the associated transaction / timing.
