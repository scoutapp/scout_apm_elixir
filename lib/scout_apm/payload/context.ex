defmodule ScoutApm.Payload.Context do
  @moduledoc """
  Converts a list of ScoutApm.Internal.Context types into an appropriate data
  structure to serialize via Jason.encode!
  """

  def new(contexts) do
    Map.merge(
      contexts_of_type(contexts, :extra),
      %{user: contexts_of_type(contexts, :user)}
    )
  end

  defp contexts_of_type(contexts, type) do
    contexts
    |> Enum.group_by(fn c -> c.type end)
    |> Map.get(type, [])
    |> Enum.map(fn c -> {c.key, c.value} end)
    |> Enum.into(%{})
  end
end
