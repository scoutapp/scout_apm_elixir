# Looks up configurations in SCOUT_* namespace, in the same manner as the Ruby agent does.
# For any given key ("monitor" for instance), it is uppercased, and prepended
# with "SCOUT_" and then looked up in the environment.
#
# If you wish to define your own environment variables to use, instead of these
# defaults, the Application config {:system, "MY_SCOUT_KEY_VAR"} approach allows
# that
defmodule ScoutApm.Config.Env do
  def load do
    :no_data
  end

  def contains?(_data, key) do
    System.get_env(env_name(key)) != nil
  end

  def lookup(_data, key) do
    System.get_env(env_name(key))
  end

  @env_prefix "SCOUT_"
  defp env_name(key) when is_atom(key), do: key |> to_string |> env_name
  defp env_name(key) when is_binary(key), do: key |> String.upcase |> (fn k -> @env_prefix <> k end).()
end
