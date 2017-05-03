defmodule ScoutApm.Internal.Trace do
  @moduledoc """
  A record of a single trace.
  """

  require Logger

  alias ScoutApm.MetricSet
  alias ScoutApm.Internal.Duration
  alias ScoutApm.Internal.Metric
  alias ScoutApm.Internal.Layer

  defstruct [
    :type,
    :name,
    :total_call_time,
    :metrics, # A metric set? Needs to distinguish between different `desc` fields
    :uri,
    :time,
    :hostname, # hack - we need to reset these server side.
    :contexts,
    :score,
  ]

  def new(type, name, duration, metrics, uri, contexts, time, hostname) do
    %__MODULE__{
      type: type,
      name: name,
      total_call_time: duration,
      metrics: metrics,
      uri: uri,
      time: time,
      hostname: hostname,
      contexts: contexts,
    }
  end

  # Creates a Trace struct from a `TracedRequest`.
  def from_tracked_request(tracked_request) do
    root_layer = tracked_request.root_layer

    duration = Layer.total_time(root_layer)

    uri = root_layer.uri

    contexts = tracked_request.contexts
    Logger.info("contexts: #{inspect(contexts)}")

    time = DateTime.utc_now() |> DateTime.to_iso8601()
    hostname = ScoutApm.Utils.hostname()

    # Metrics scoped & stuff. Distinguished by type, name, scope, desc
    metric_set = create_trace_metrics(
      root_layer,
      ScoutApm.Collector.request_scope(tracked_request),
      true,
      MetricSet.new(%{compare_desc: true, collapse_all: true}))

    __MODULE__.new(root_layer.type, root_layer.name, duration, MetricSet.to_list(metric_set), uri, contexts, time, hostname)
  end

  # Each layer creates two Trace metrics:
  # - a detailed one distinguished by type/name/scope/desc
  # - a summary one distinguished only by type
  #
  # TODO:
  #   Layers inside of Layers isn't scoped fully here. The recursive call
  #   should figure out if we need to update the scope we're passing down the
  #   tree.
  #
  #   In ruby land, that would be a situation like:
  #   Controller
  #     DB         <-- scoped under controller
  #     View
  #       DB       <-- scoped under View
  #
  # ignore_scope option is to skip attaching a scope to the root layer (a controller shouldn't be "scoped" under itself).
  # The recursive call resets it to not be skipped, so children layers all will be attached to the scope correctly.
  defp create_trace_metrics(layer, scope, ignore_scope, %MetricSet{} = metric_set) do
    detail_metric = Metric.from_layer(layer, (if ignore_scope, do: nil, else: scope))
    summary_metric = Metric.from_layer_as_summary(layer)

    # Absorb each child recursively
    Enum.reduce(layer.children, metric_set, fn child, set -> create_trace_metrics(child, scope, false, set) end)
    # Then absorb this layer's 2 metrics
    |> MetricSet.absorb(detail_metric)
    |> MetricSet.absorb(summary_metric)
  end

  defp key(%__MODULE__{} = trace) do
    trace.type <> "/" <> trace.name
  end

  #####################
  #  Scoring a trace  #
  #####################

  @point_multiplier_speed 0.25
  @point_multiplier_percentile 1.0

  def as_scored_item(%__MODULE__{} = trace) do
    {{:score, score(trace), key(trace)}, trace}
  end

  def score(%__MODULE__{} = trace) do
    duration_score(trace) + percentile_score(trace)
  end

  defp duration_score(%__MODULE__{} = trace) do
    :math.log(1 + Duration.as(trace.total_call_time, :seconds)) * @point_multiplier_speed
  end

  defp percentile_score(%__MODULE__{} = trace) do
    with {:ok, percentile} <- ScoutApm.PersistentHistogram.percentile_for_value(
                                key(trace),
                                Duration.as(trace.total_call_time, :seconds))
      do
        raw = cond do
          # Don't put much emphasis on capturing low percentiles.
          percentile < 40 ->
            0.4

          # Higher here to get more "normal" mean traces
          percentile < 60 ->
            1.4

          # Between 60 & 90% is fine.
          percentile < 90 ->
            0.7

          # Highest here to get 90+%ile traces
          percentile >= 90 ->
            1.8
        end

        raw * @point_multiplier_percentile
    else
      # If we failed to lookup the percentile, just give back a 0 score.
      err ->
        Logger.debug("Failed to get percentile_score, error: #{err}")
        0
    end
  end
end
