# Reads values set in mix configuration
#
# Supports the {:system, "MY_ENV_VAR"} syntax, in the same manner as many other libraries
defmodule ScoutApm.Config.Application do
  def load do
    :no_data
  end

  def contains?(_data, key) do
    Application.get_env(:scout_apm, key) != nil
  end

  def lookup(_data, key) do
    Application.get_env(:scout_apm, key) |> resolve
  end

  # Takes "raw" values from various config sources, and if those values are
  # in {:system, "VAR_NAME"} format it loads VAR_NAME value from ENV
  defp resolve({:system, value}), do: System.get_env(value)
  defp resolve(value), do: value
end
