defmodule ScoutApm.Config do
  @moduledoc """
  Public interface to configuration settings. Reads from several configuration
  sources, giving each an opportunity to respond with its value before trying
  the next.

  Application.get_env, and Defaults are the the current ones, with
  an always-nil at the end of the chain.
  """

  alias ScoutApm.Config.Coercions

  @config_modules [
    {ScoutApm.Config.Env, ScoutApm.Config.Env.load()},
    {ScoutApm.Config.Application, ScoutApm.Config.Application.load()},
    {ScoutApm.Config.Defaults, ScoutApm.Config.Defaults.load()},
    {ScoutApm.Config.Null, ScoutApm.Config.Null.load()},
  ]

  def find(key) do
    Enum.reduce_while(@config_modules, nil, fn {mod, data}, _acc ->
      if mod.contains?(data, key) do
        raw = mod.lookup(data, key)
        case coercion(key).(raw) do
          {:ok, c} ->
            {:halt, c}
          :error ->
            ScoutApm.Logger.log(:info, "Coercion of configuration #{key} failed. Ignoring")
            {:cont, nil}
        end
    else
      {:cont, nil}
      end
    end)
  end

  defp coercion(:monitor), do: &Coercions.boolean/1
  defp coercion(:ignore), do: &Coercions.json/1
  defp coercion(_), do: fn x -> {:ok, x} end
end
