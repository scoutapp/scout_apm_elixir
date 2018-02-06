defmodule ScoutApm.Config.Defaults do
  def load do
    %{
      host: "https://checkin.scoutapp.com",
      direct_host: "https://apm.scoutapp.com",
      dev_trace: false,
      monitor: true,
      ignore: []
    }
  end

  def contains?(data, key) do
    data[key] != nil
  end

  def lookup(data, key) do
    data[key]
  end
end
