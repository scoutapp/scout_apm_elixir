defmodule ScoutApm.Instrumentation do
  defmacro __using__(_arg) do
    quote do
      plug ScoutApm.Plugs.ControllerTimer
      alias TestappPhoenix.Repo.ScoutApm, as: Repo
    end
  end
end

