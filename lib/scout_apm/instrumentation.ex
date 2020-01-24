defmodule ScoutApm.Instrumentation do
  defmacro __using__(opts) do
    timer_options = Keyword.take(opts, [:include_application_name])

    quote do
      plug(ScoutApm.DevTrace.Plug)
      plug(ScoutApm.Plugs.ControllerTimer, unquote(timer_options))
    end
  end
end
