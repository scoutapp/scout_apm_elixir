defmodule ScoutApm.DevTrace do
  def enabled? do
    ScoutApm.Config.find(:dev_trace)
  end
end
