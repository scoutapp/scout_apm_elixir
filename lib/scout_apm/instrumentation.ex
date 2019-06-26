defmodule ScoutApm.Instrumentation do
  defmacro __using__(_arg) do
    quote do
      plug(ScoutApm.DevTrace.Plug)
      plug(ScoutApm.Plugs.ControllerTimer)
    end
  end
end
