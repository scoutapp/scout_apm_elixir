x merge each timing into a MetricSet
x assemble & send payload each minute
x setup configuration settings (key)
x fix scope arg in payload

* instrument Ecto
* instrument Phoneix views (Eex & the other one?)
* instrument hackney?
* instrument httpoison?

* reimplement scope arg in MetricSet & Payload
* separate polling genserver?
* figure out how to connect a trace together
* how do I capture a backtrace at runtime? ("Where did this ecto query run")
* add a way to capture trace context
* how can we track a trace across processes? Tasks?

