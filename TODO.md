x merge each timing into a MetricSet
x assemble & send payload each minute
x setup configuration settings (key)
x fix scope arg in payload
x reimplement scope arg in MetricSet & Payload
x instrument Ecto via Log Integration
x how do I capture a backtrace at runtime? (`Process.info(pid, :current_stacktrace)`)

* instrument Ecto via Wrapper module
* instrument Phoneix views (Eex & the other one?)
* instrument Phoenix channels
* instrument hackney?
  - see a VCR testing lib that mocks hackney: https://github.com/parroty/exvcr

* split out the types in a TrackedRequest / Layer / Payload.* / etc.
* ecto wrapper module that supports multi-repo env?
* configure a logger
* configuration file
* separate polling genserver?
* figure out how to connect a trace together
* add a way to capture trace context
* how can we track a trace across processes? Tasks?
  - Task does "$ancestors" key
* Investigate what monitoring channels means.
* Standardize handling of time. Is everything fractional seconds? milli or micro seconds?
* Add typespecs to the types
* Validate we don't break ecto migration generation or running

