defmodule ScoutApm.AgentNote do
  @moduledoc """
  A centralized place to log & note any agent misconfigurations, interesting
  occurances, or other things that'd normally be log messages.
  """

  require Logger

  def note({:metric_type, :over_limit, max_types}) do
    Logger.info("Skipping absorbing metric, over limit of #{max_types} unique metric types. See http://help.apm.scoutapp.com/#elixir-agent for more details")
  end
end
