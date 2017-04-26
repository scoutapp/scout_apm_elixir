defmodule ScoutApm.Collector do
  alias ScoutApm.MetricSet
  alias ScoutApm.Internal.Duration
  alias ScoutApm.Internal.Metric
  alias ScoutApm.Internal.Trace
  alias ScoutApm.Internal.Layer

  def record_async(tracked_request) do
    Task.start(fn -> record(tracked_request) end)
  end

  # Determine scope. Then starting with the root layer, track
  # all the layers, recursing down the tree of children
  def record(tracked_request) do
    scope = request_scope(tracked_request)
    store_histograms(tracked_request)
    store_metrics(tracked_request.root_layer, scope)
    store_trace(tracked_request)
  end

  # For now, scope is simply the root layer
  def request_scope(tracked_request) do
    rl = tracked_request.root_layer
    %{type: rl.type, name: rl.name}
  end

  ########################
  #  Collect Histograms  #
  ########################
  def store_histograms(tracked_request) do
    root_layer = tracked_request.root_layer
    duration = Layer.total_time(root_layer)
    key = "#{root_layer.type}/#{root_layer.name}"

    # Store into this minute's histogram
    ScoutApm.Store.record_per_minute_histogram(key, duration)

    # Store into the long-running histogram
    ScoutApm.PersistentHistogram.record_timing(key, Duration.as(duration, :seconds))
  end

  ####################
  #  Collect Metric  #
  ####################

  def store_metrics(layer, scope) do
    # Track self
    ScoutApm.Store.record_metric(Metric.from_layer(layer, scope))

    # Recurse into any children.
    # This isn't tail recursive, probably no biggie
    Enum.each(layer.children, fn child -> store_metrics(child, scope) end)
  end

  ###################
  #  Collect Trace  #
  ###################

  def store_trace(tracked_request) do
    root_layer = tracked_request.root_layer

    duration = Layer.total_time(root_layer)

    uri = root_layer.uri

    # TODO: extract this once we store it in tracked_request
    context = %{}

    time = DateTime.utc_now() |> DateTime.to_iso8601()
    hostname = ScoutApm.Utils.hostname()

    # Metrics scoped & stuff. Distinguished by type, name, scope, desc
    metric_set = create_trace_metrics(
      root_layer,
      request_scope(tracked_request),
      true,
      MetricSet.new(%{compare_desc: true, collapse_all: true}))

    trace = Trace.new(root_layer.type, root_layer.name, duration, MetricSet.to_list(metric_set), uri, context, time, hostname)
    ScoutApm.Store.record_trace(trace)
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
end
