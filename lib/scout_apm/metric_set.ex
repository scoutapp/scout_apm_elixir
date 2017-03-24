defmodule ScoutApm.MetricSet do
  @moduledoc """
  A way to absorb & combine metrics into a single set, keeping track of min/max/count, etc.

  While this is just a map underneath, treat it like an opaque data type.
  """

  @type t :: %__MODULE__{data: map, options: ScoutApm.MetricSet.options}
  @type options :: %{collapse_all: boolean(), compare_desc: boolean()}

  defstruct [
    :options,
    :data
  ]

  require Logger

  alias ScoutApm.Internal.Metric


  @spec new() :: ScoutApm.MetricSet.t
  def new do
    new(%{collapse_all: false, compare_desc: false})
  end

  @spec new(ScoutApm.MetricSet.options) :: ScoutApm.MetricSet.t
  def new(options) do
    %__MODULE__{
      options: options,
      data: %{},
    }
  end

  def absorb(%__MODULE__{} = metric_set, %Metric{} = metric) do
    Logger.info("Absorbing #{metric.type}, #{metric.name}, scope: #{inspect metric.scope}")
    {global_key, scoped_key} = keys(metric, metric_set.options)

    new_data = Map.update(
      metric_set.data, scoped_key, metric,
      fn m2 -> Metric.merge(stripped_metric(metric, metric_set.options), m2) end)

    %{ metric_set | data: new_data }
  end

  # Ditches the key part, and just returns the aggregate metric
  @spec to_list(__MODULE__.t) :: list(Metric.t)
  def to_list(%__MODULE__{} = metric_set) do
    metric_set.data
    |> Map.to_list
    |> Enum.map(fn {_,x} -> x end)
  end

  #####################
  #  Private Helpers  #
  #####################

  defp keys(%Metric{} = metric, %{} = options) do
    {
      global_key(metric, options),
      scoped_key(metric, options),
    }
  end

  defp global_key(metric, %{collapse_all: collapse_all}) do
    case collapse_all do
      false ->
        "#{metric.type}/#{metric.name}"
      true ->
        "#{metric.type}/all"
    end
  end

  # Always with the full key (type + name)
  # Then optionally with the desc field too
  defp scoped_key(metric, %{compare_desc: compare_desc}) do
    case compare_desc do
      true ->
        "#{metric.type}/#{metric.name}/scope/#{metric.scope[:type]}/#{metric.scope[:name]}/desc/#{metric.desc}"
      false ->
        "#{metric.type}/#{metric.name}/scope/#{metric.scope[:type]}/#{metric.scope[:name]}"
    end
  end

  defp stripped_metric(%Metric{} = metric, %{compare_desc: compare_desc}) do
    case compare_desc do
      true -> metric
      false -> %Metric{metric | desc: nil}
    end
  end
end

