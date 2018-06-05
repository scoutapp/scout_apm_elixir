defmodule ScoutApm.Cache do
  @moduledoc false
  @table_name :scout_cache

  def setup do
    :ets.new(@table_name, [:named_table, :set, :protected, read_concurrency: true])

    {:ok, hostname} = :inet.gethostname()
    hostname = to_string(hostname)

    :ets.insert(@table_name, {:hostname, hostname})
  end

  def hostname do
    case :ets.lookup(@table_name, :hostname) do
      [{:hostname, hostname}] -> hostname
      _ -> nil
    end
  end
end
