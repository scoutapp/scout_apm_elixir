defmodule ScoutApm.Instrumentation do
  defmacro __using__(arg) do
    quote do
      plug ScoutApm.Plugs.ControllerTimer
      alias ScoutApm.Repo, as: Repo
    end
  end
end

