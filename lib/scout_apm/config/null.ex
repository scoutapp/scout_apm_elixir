defmodule ScoutApm.Config.Null do
  @moduledoc """
  Always says it contains key, and the value is always nil
  """

  def load do
    :null
  end

  def contains?(_data, key) do
    true
  end

  def lookup(_data, key) do
    nil
  end
end
