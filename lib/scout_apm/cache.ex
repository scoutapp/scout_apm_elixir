defmodule ScoutApm.Cache do
  @moduledoc false
  @table_name :scout_cache

  def setup do
    :ets.new(@table_name, [:named_table, :set, :protected, read_concurrency: true])

    :ets.insert(@table_name, {:hostname, determine_hostname()})
  end

  def hostname do
    case :ets.lookup(@table_name, :hostname) do
      [{:hostname, hostname}] -> hostname
      _ -> nil
    end
  end

  defp determine_hostname do
    case heroku_hostname() do
      hostname when is_binary(hostname) -> hostname
      _ -> inet_hostname()
    end
  end

  defp heroku_hostname do
    System.get_env("DYNO")
  end

  defp inet_hostname do
    {:ok, hostname} = :inet.gethostname()
    to_string(hostname)
  end
end
