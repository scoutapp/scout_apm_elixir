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
  def boolean(s) when s in @truthy, do: {:ok, true}
  def boolean(s) when s in @falsey, do: {:ok, false}

  def boolean(s) when is_binary(s) do
    downcased = String.downcase(s)

    if downcased != s do
      boolean(downcased)
    else
      :error
    end
  end

  def boolean(_), do: :error

  def json(json) when is_list(json), do: {:ok, json}
  def json(json) when is_map(json), do: {:ok, json}

  def json(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, json} -> {:ok, json}
      {:error, _} -> :error
    end
  end

  def json(_), do: :error

  @valid_log_levels [:debug, :info, :warn, :warning, :error]
  def log_level(level) when is_atom(level) and level in @valid_log_levels, do: {:ok, level}

  def log_level(level) when is_binary(level) do
    atom_level = String.to_existing_atom(String.downcase(level))
    log_level(atom_level)
  rescue
    ArgumentError -> :error
  end

  def log_level(_), do: :error
end
