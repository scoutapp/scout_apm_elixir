defmodule ScoutApm.Internal.Context do
  @moduledoc """
  Internal representation of a Context. As a user of ScoutApm, you
  likely will not need this module
  """

  defstruct [:key, :value]

  def new(key, value) do
    case {valid_key?(key), valid_value?(value)} do
      {false, true} ->
        {:error, {:key, :invalid_type}}

      {false, false} ->
        {:error, {:key, :invalid_type}}

      {true, false} ->
        {:error, {:value, :invalid_type}}

      {true, true} ->
        {:ok, %__MODULE__{key: key, value: value}}
    end
  end

  defp valid_key?(key) when is_binary(key), do: String.printable?(key)
  defp valid_key?(_), do: false

  defp valid_value?(val) when is_binary(val), do: String.printable?(val)
  defp valid_value?(val) when is_boolean(val), do: true
  defp valid_value?(val) when is_number(val), do: true
  defp valid_value?(_), do: false
end
