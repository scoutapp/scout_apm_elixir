defmodule ScoutApm.Internal.Context do
  @moduledoc """
  Internal representation of a Context. As a user of ScoutApm, you
  likely will not need this module
  """

  defstruct [:type, :key, :value]

  @valid_types [:user, :extra]
  @type context_types :: :user | :extra

  @type t :: %__MODULE__{
    type: context_types,
    key: String.t,
    value: number | boolean | String.t,
  }

  def new(type, key, value) do
    case {valid_type?(type), valid_key?(key), valid_value?(value)} do
      {false, _, _} ->
        {:error, {:type, :invalid}}

      {_, false, _} ->
        {:error, {:key, :invalid_type}}

      {_, _, false} ->
        {:error, {:value, :invalid_type}}

      {true, true, true} ->
        {:ok, %__MODULE__{type: type, key: key, value: value}}
    end
  end

  defp valid_type?(t) when t in @valid_types, do: true
  defp valid_type?(_), do: false

  defp valid_key?(key) when is_binary(key), do: String.printable?(key)
  defp valid_key?(key) when is_atom(key), do: key |> to_string |> String.printable?
  defp valid_key?(_), do: false

  defp valid_value?(val) when is_binary(val), do: String.printable?(val)
  defp valid_value?(val) when is_boolean(val), do: true
  defp valid_value?(val) when is_number(val), do: true
  defp valid_value?(_), do: false
end
