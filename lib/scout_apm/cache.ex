defmodule ScoutApm.Cache do
  @moduledoc false
  @table_name :scout_cache

  def setup do
    :ets.new(@table_name, [:named_table, :set, :protected, read_concurrency: true])

    :ets.insert(@table_name, {:hostname, determine_hostname()})
    :ets.insert(@table_name, {:git_sha, determine_git_sha()})
  end

  ######################################
  #  Public Functions to Lookup Values #
  ######################################

  def hostname do
    case :ets.lookup(@table_name, :hostname) do
      [{:hostname, hostname}] -> hostname
      _ -> nil
    end
  end

  def git_sha do
    case :ets.lookup(@table_name, :git_sha) do
      [{:git_sha, hostname}] -> hostname
      _ -> nil
    end
  end

  ########################
  #  Hostname Detection  #
  ########################

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

  #######################
  #  Git SHA Detection  #
  #######################

  # Lookup via explicitly configured values, then if not, fall back to a heroku
  # setting, then ... nil
  def determine_git_sha do
    case configured_sha() do
      sha when is_binary(sha) -> sha
      _ -> heroku_sha()
    end
  end

  defp heroku_sha do
    System.get_env("HEROKU_SLUG_COMMIT")
  end

  # Looks in all normal configuration locations (Application, {:system, ENV}, ENV)
  defp configured_sha do
    ScoutApm.Config.find(:revision_sha)
  end
end
