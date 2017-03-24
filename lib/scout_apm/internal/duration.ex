defmodule ScoutApm.Internal.Duration do
  @type t :: %__MODULE__{value: number()}
  @type unit :: :microseconds | :milliseconds | :seconds

  defstruct [
    :value
  ]

  @spec zero() :: __MODULE__.t
  def zero(), do: %__MODULE__{value: 0}

  @spec new(number(), __MODULE__.unit) :: __MODULE__.t
  def new(value, unit) do
    %__MODULE__{value: normalize_value(value, unit)}
  end

  @spec as(__MODULE__.t, __MODULE__.unit) :: number()
  def as(%__MODULE__{value: value}, :microseconds), do: value
  def as(%__MODULE__{value: value}, :milliseconds), do: value / 1_000
  def as(%__MODULE__{value: value}, :seconds), do: value / 1_000_000

  @spec add(__MODULE__.t, __MODULE__.t) :: __MODULE__.t
  def add(%__MODULE__{value: v1}, %__MODULE__{value: v2}) do
    %__MODULE__{value: v1 + v2}
  end

  @spec subtract(__MODULE__.t, __MODULE__.t) :: __MODULE__.t
  def subtract(%__MODULE__{value: v1}, %__MODULE__{value: v2}) do
    %__MODULE__{value: v1 - v2}
  end

  @spec min(__MODULE__.t, __MODULE__.t) :: __MODULE__.t
  def min(%__MODULE__{value: v1}, %__MODULE__{value: v2}) do
    cond do
      v1 < v2 -> %__MODULE__{value: v1}
      v2 < v1 -> %__MODULE__{value: v2}
      v1 == v2 -> %__MODULE__{value: v1}
    end
  end

  @spec max(__MODULE__.t, __MODULE__.t) :: __MODULE__.t
  def max(%__MODULE__{value: v1}, %__MODULE__{value: v2}) do
    cond do
      v1 > v2 -> %__MODULE__{value: v1}
      v2 > v1 -> %__MODULE__{value: v2}
      v1 == v2 -> %__MODULE__{value: v1}
    end
  end

  defp normalize_value(value, :microseconds), do: value
  defp normalize_value(value, :milliseconds), do: value * 1000
  defp normalize_value(value, :seconds), do: value * 1_000_000
end
