defmodule ScoutApm.MetricSet do
  @moduledoc """
  A way to absorb & combine metrics into a single set, keeping track of min/max/count, etc.

  While this is just a map underneath, treat it like an opaque data type.
  """

  @type t :: %__MODULE__{
    data: map,
    options: options,
    types: MapSet.t,
  }

  @type options :: %{
    collapse_all: boolean(),
    compare_desc: boolean(),
    max_types: non_neg_integer(),
  }

  defstruct [
    :options,
    :data,
    :types,
  ]

  # Maximum number of unique types. This is far larger than what you'd really
  # want, and only acts as a safety valve. If you're doing custom
  # instrumentation, keep the metric type field very simple. "HTTP", "JSON",
  # and similar.
  @max_types 100

  alias ScoutApm.Internal.Metric

  @default_options %{
    collapse_all: false,
    compare_desc: false,
    max_types: @max_types,
  }

  @spec new() :: ScoutApm.MetricSet.t
  def new, do: new(@default_options)

  @spec new(map()) :: t
  def new(options) do
    resolved_options = Map.merge(@default_options, options)
    %__MODULE__{
      options: resolved_options,
      data: %{},
      types: MapSet.new(),
    }
  end

  @spec absorb(t, Metric.t) :: t
  def absorb(%__MODULE__{} = metric_set, %Metric{} = metric) do
    if under_type_limit?(metric_set) do
      metric_set
      |> absorb_no_type_limit(metric)
      |> register_type(metric.type)
    else
      # Don't actually absorb, this is over limit.
      ScoutApm.AgentNote.note({:metric_type, :over_limit, metric_set.options.max_types})
      metric_set
    end
  end

  # Ditches the key part, and just returns the aggregate metric
  @spec to_list(t) :: list(Metric.t)
  def to_list(%__MODULE__{} = metric_set) do
    metric_set.data
    |> Map.to_list
    |> Enum.map(fn {_,x} -> x end)
  end

  #####################
  #  Private Helpers  #
  #####################

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

  # Have we hit the safety-valve limit of types?
  defp under_type_limit?(%__MODULE__{} = metric_set) do
    MapSet.size(metric_set.types) < metric_set.options.max_types
  end

  defp absorb_no_type_limit(%__MODULE__{} = metric_set, %Metric{} = metric) do
    scoped_key = scoped_key(metric, metric_set.options)
    new_data = Map.update(
      metric_set.data, scoped_key, metric,
      fn m2 -> Metric.merge(stripped_metric(metric, metric_set.options), m2) end)

    %{metric_set | data: new_data}
  end

  defp register_type(%__MODULE__{} = metric_set, type) do
    %{metric_set | types: MapSet.put(metric_set.types, type)}
  end

end

