defmodule ScoutApm.Collector do
  import Logger

  alias ScoutApm.Internal.Metric

  def record_async(tracked_request) do
    Task.start(fn -> record(tracked_request) end)
  end

  # Determine scope. Then starting with the root layer, track
  # all the layers, recursing down the tree of children
  def record(tracked_request) do
    scope = request_scope(tracked_request)
    create_metrics(tracked_request.root_layer, scope)
  end

  # For now, scope is simply the root layer
  def request_scope(tracked_request) do
    rl = tracked_request.root_layer
    %{type: rl.type, name: rl.name}
  end

  def create_metrics(layer, scope) do
    # Track self
    ScoutApm.Store.record_metric(Metric.from_layer(layer, scope))

    # Recurse into any children.
    # This isn't tail recursive, probably no biggie
    Enum.each(layer.children, fn child -> create_metrics(child, scope) end)
  end
end
