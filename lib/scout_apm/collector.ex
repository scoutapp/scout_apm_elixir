defmodule ScoutApm.Collector do
  @callback send(map()) :: :ok
end
