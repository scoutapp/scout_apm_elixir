defmodule ScoutApm.Config.Coercions do
  @moduledoc """
  Takes "raw" values from various config sources, and turns them into the
  requested format.
  """

  @doc """
  Returns {:ok, true}, {:ok, false}, or :error
  Attempts to "parse" a string
  """
  @truthy ["true", "t", "1"]
  @falsey ["false", "f", "0"]
  def boolean(b) when is_boolean(b), do: {:ok, b}
  def boolean(s) when s in @truthy,  do: {:ok, true}
  def boolean(s) when s in @falsey,  do: {:ok, false}
  def boolean(s) when is_binary(s) do
    downcased = String.downcase(s)
    if downcased != s do
      boolean(downcased)
    else
      :error
    end
  end
  def boolean(_), do: :error


  def json(json) when is_list(json), do: json
  def json(json) when is_map(json), do: json
  def json(json) when is_binary(json) do
    case Poison.decode(json) do
      {:ok, json} -> {:ok, json}
      {:error, _} -> :error
    end
  end
  def json(_), do: :error
end
