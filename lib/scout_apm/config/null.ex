defmodule ScoutApm.Config.Null do
  @moduledoc """
  Always says it contains key, and the value is always nil
  """

  def load do
    :null
  end

  def contains?(_data, _key) do
    true
  end

  def lookup(_data, _key) do
    nil
  end
end
