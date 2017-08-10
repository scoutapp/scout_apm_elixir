defmodule ScoutApm.Config.Env do
  @moduledoc """
  Takes "raw" values from various config sources, and if those values are
  in {:system, "VAR_NAME"} format it loads VAR_NAME value from ENV
  """

  def parse({:system, value}), do: System.get_env(value)
  def parse(value), do: value
end
