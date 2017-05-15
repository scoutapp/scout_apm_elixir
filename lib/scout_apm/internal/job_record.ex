defmodule ScoutApm.Internal.JobRecord do
  @moduledoc """
  Stores a single or multiple runs of a background job.
  Both metadata ("queue" and "name"), and metrics ("total time", "metrics")
  """

  alias ScoutApm.MetricSet
  alias ScoutApm.Internal.Metric
  alias ScoutApm.Internal.Layer
  alias ScoutApm.Internal.Duration

  @type t :: %__MODULE__{
    queue: String.t,
    name: String.t,
    count: non_neg_integer,
    errors: non_neg_integer,
    total_time: ApproximateHistogram.t,
    exclusive_time: ApproximateHistogram.t,
    metrics: MetricSet.t,
  }

  defstruct [
    :queue,
    :name,

    :count,
    :errors,

    :total_time,
    :exclusive_time,

    :metrics,
  ]

  ##################
  #  Construction  #
  ##################

  @spec from_layer(Layer.t, any) :: t
  @doc """
  Given a Job layer (probably the root-layer of a TrackedRequest), turn it
  into a JobRecord, with fully populated metrics and timing info
  """
  def from_layer(%Layer{type: type} = layer, scope) when type == "Job" do
    queue_name = "default"

    %__MODULE__{
      queue: queue_name,
      name: layer.name,
      count: 1,
      errors: 0,
      total_time: ApproximateHistogram.add(
        ApproximateHistogram.new(),
        layer |> Layer.total_time() |> Duration.as(:seconds)),
      exclusive_time: ApproximateHistogram.add(
        ApproximateHistogram.new(),
        layer |> Layer.total_exclusive_time() |> Duration.as(:seconds)),
      metrics: create_metrics(layer, scope, MetricSet.new()),
    }
  end

  # Depth-first walk of the layer tree, diving all the way to the leaf
  # nodes, then collecting the child and its peers as its walked back up
  # the call stack to the parent
  defp create_metrics(%Layer{} = layer, scope, %MetricSet{} = metric_set) do
    # Collect up all children layers' metrics first

    layer.children
    |> Enum.reduce(metric_set, fn child, set -> create_metrics(child, scope, set) end)

    # Then collect this layer's metrics
    |> MetricSet.absorb(Metric.from_layer(layer, %{}))
  end

  @spec key(t) :: String.t
  def key(%__MODULE__{} = job_record) do
    job_record.queue <> "/" <> job_record.name
  end


  #######################
  #  Updater Functions  #
  #######################

  @spec merge(t, t) :: t
  def merge(%__MODULE__{queue: queue1, name: name1} = m1,
            %__MODULE__{queue: queue2, name: name2} = m2)
            when queue1 == queue2
             and name1 == name2
            do
    %__MODULE__{
      queue: m1.queue,
      name: m1.name,

      count: m1.count + m2.count,
      errors: m1.errors + m2.errors,

      total_time: merge_histos(m1.total_time, m2.total_time),
      exclusive_time: merge_histos(m1.exclusive_time, m2.exclusive_time),
      metrics: MetricSet.merge(m1.metrics, m2.metrics),
    }
  end

  defp merge_histos(h1, h2) do
    h1
    |> ApproximateHistogram.to_list
    |> Enum.reduce(h2, fn {val, count}, memo ->
      Enum.reduce(1..count, memo, fn _, m -> ApproximateHistogram.add(m, val) end)
    end)
  end

  #############
  #  Queries  #
  #############

end
