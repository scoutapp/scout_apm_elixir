defmodule ScoutApm.Payload.Context do
  @moduledoc """
  Converts a list of ScoutApm.Internal.Context types into an appropriate data
  structure to serialize via Poison.encode!
  """

  def new(contexts) do
    contexts
    |> Enum.map(fn c -> {c.key, c.value} end)
    |> Enum.into(%{})
  end
end
