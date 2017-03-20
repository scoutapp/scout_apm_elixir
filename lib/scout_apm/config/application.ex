defmodule ScoutApm.Config.Application do
  def load do
    :no_data
  end

  def contains?(_data, key) do
    Application.get_env(:scout_apm, key) != nil
  end

  def lookup(_data, key) do
    Application.get_env(:scout_apm, key)
  end
end
