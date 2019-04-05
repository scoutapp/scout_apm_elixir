defmodule ScoutApm.Collector do
  @moduledoc """
  Takes a TrackedRequest, and routes it onward to the correct Store
  """

  alias ScoutApm.Internal.Duration
  alias ScoutApm.Internal.Metric
  alias ScoutApm.Internal.WebTrace
  alias ScoutApm.Internal.JobTrace
  alias ScoutApm.Internal.Layer
  alias ScoutApm.Internal.JobRecord
  alias ScoutApm.{ScopeStack, TrackedRequest}

  def record_async(tracked_request) do
    Task.start(fn -> record(tracked_request) end)
  end

  # Determine scope. Then starting with the root layer, track
  # all the layers, recursing down the tree of children
  def record(tracked_request) do
    store_histograms(tracked_request)

    case categorize(tracked_request) do
      :web ->
        maybe_store_web_error_metric(tracked_request)

        store_web_metrics(
          tracked_request.root_layer,
          ScopeStack.layer_to_scope(tracked_request.root_layer)
        )

        store_web_trace(tracked_request)
        :ok

      :job ->
        store_job_metrics(tracked_request, ScopeStack.layer_to_scope(tracked_request.root_layer))
        store_job_trace(tracked_request)
        :ok

      # If it's something else, I don't know what to do with it.  This,
      # or categorize will likely need to be smarter in the future
      _ ->
        :skipped
    end
  end

  ########################
  #  Collect Histograms  #
  ########################

  def store_histograms(tracked_request) do
    root_layer = tracked_request.root_layer
    duration = Layer.total_time(root_layer)

    # TODO: This knowledge of how to build a key is here, and in score_key of WebTrace & JobTrace modules
    key = "#{root_layer.type}/#{root_layer.name}"

    # Store into this minute's histogram
    ScoutApm.Store.record_per_minute_histogram(key, duration)

    # Store into the long-running histogram
    ScoutApm.PersistentHistogram.record_timing(key, Duration.as(duration, :seconds))
  end

  ####################
  #  Collect Metric  #
  ####################

  def store_web_metrics(layer, scope) do
    # Track self
    ScoutApm.Store.record_web_metric(Metric.from_layer(layer, scope))

    # Recurse into any children.
    # This isn't tail recursive, probably no biggie
    Enum.each(layer.children, fn child -> store_web_metrics(child, scope) end)
  end

  # Create a JobRecord, and store that?
  def store_job_metrics(tracked_request, scope) do
    record = JobRecord.from_layer(tracked_request.root_layer, scope)

    record =
      if(tracked_request.error) do
        JobRecord.increment_errors(record)
      else
        record
      end

    ScoutApm.Store.record_job_record(record)
  end

  ###################
  #  Collect Trace  #
  ###################

  def store_web_trace(tracked_request) do
    tracked_request
    |> WebTrace.from_tracked_request()
    |> ScoutApm.Store.record_web_trace()
  end

  def store_job_trace(tracked_request) do
    tracked_request
    |> JobTrace.from_tracked_request()
    |> ScoutApm.Store.record_job_trace()
  end

  #############
  #  Helpers  #
  #############

  defp categorize(tracked_request) do
    case tracked_request.root_layer.type do
      "Controller" -> :web
      "Job" -> :job
      _ -> :unknown
    end
  end

  defp maybe_store_web_error_metric(%TrackedRequest{error: true, root_layer: %Layer{}} = request) do
    root_layer = request.root_layer
    name = "#{root_layer.type}/#{root_layer.name}"
    time = Duration.new(1, :microseconds)

    metric = %Metric{
      type: "Errors",
      name: name,
      call_count: 1,
      total_time: time,
      exclusive_time: time,
      min_time: time,
      max_time: time
    }

    ScoutApm.Store.record_web_metric(metric)

    request
  end

  defp maybe_store_web_error_metric(request), do: request
end
