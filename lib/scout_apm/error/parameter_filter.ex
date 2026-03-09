defmodule ScoutApm.Error.ParameterFilter do
  @moduledoc """
  Filters sensitive parameters from request data before sending to Scout APM.
  Matches the Python agent's FILTER_PARAMETERS list.
  """

  @default_filter_parameters MapSet.new([
                               "access",
                               "access_token",
                               "api_key",
                               "apikey",
                               "auth",
                               "auth_token",
                               "card[number]",
                               "certificate",
                               "credentials",
                               "crypt",
                               "key",
                               "mysql_pwd",
                               "otp",
                               "passwd",
                               "password",
                               "private",
                               "protected",
                               "salt",
                               "secret",
                               "secret_key",
                               "ssn",
                               "stripetoken",
                               "token"
                             ])

  @filtered_value "[FILTERED]"

  @doc """
  Filters sensitive parameters from a map or nil value.
  """
  @spec filter(map() | list() | nil) :: map() | list() | nil
  def filter(nil), do: nil
  def filter(params) when is_map(params), do: filter_map(params)
  def filter(params) when is_list(params), do: Enum.map(params, &filter_value/1)
  def filter(value), do: value

  defp filter_map(map) do
    filter_params = get_filter_parameters()

    map
    |> Enum.map(fn {key, value} ->
      key_str = to_string(key) |> String.downcase()

      if MapSet.member?(filter_params, key_str) do
        {key, @filtered_value}
      else
        {key, filter_value(value)}
      end
    end)
    |> Map.new()
  end

  defp filter_value(value) when is_map(value), do: filter_map(value)
  defp filter_value(value) when is_list(value), do: Enum.map(value, &filter_value/1)
  defp filter_value(nil), do: nil

  defp filter_value(value) do
    case value do
      v when is_binary(v) -> v
      v when is_number(v) -> v
      v when is_boolean(v) -> v
      v when is_atom(v) -> Atom.to_string(v)
      v -> inspect(v, limit: 100)
    end
  end

  defp get_filter_parameters do
    custom = ScoutApm.Config.find(:errors_filter_parameters) || []

    custom
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.downcase/1)
    |> MapSet.new()
    |> MapSet.union(@default_filter_parameters)
  end
end
