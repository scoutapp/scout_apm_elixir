defmodule ScoutApm.Collector do
  @moduledoc """
  Takes a TrackedRequest, and routes it onward to the correct Store
  """

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
    store_web_trace(tracked_request)
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
    ScoutApm.Store.record_web_metric(Metric.from_layer(layer, scope))

    # Recurse into any children.
    # This isn't tail recursive, probably no biggie
    Enum.each(layer.children, fn child -> store_metrics(child, scope) end)
  end

  ###################
  #  Collect Trace  #
  ###################

  def store_web_trace(tracked_request) do
    tracked_request
    |> Trace.from_tracked_request()
    |> ScoutApm.Store.record_web_trace()
  end

end
