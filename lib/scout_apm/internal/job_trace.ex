defmodule ScoutApm.Internal.JobTrace do
  alias ScoutApm.Internal.Context
  alias ScoutApm.Internal.Duration
  alias ScoutApm.Internal.Metric
  alias ScoutApm.Internal.Layer
  alias ScoutApm.MetricSet
  alias ScoutApm.ScopeStack

  defstruct [
    :queue_name,
    :job_name,

    # When did this job occur
    :time,

    # What else interesting did we learn?
    :contexts,

    :total_time,
    :exclusive_time,

    :metrics,

    :hostname,
    :score,
  ]

  @type t :: %__MODULE__{
    queue_name: String.t,
    job_name: String.t,

    # When did this job occur
    time: any,

    # What else interesting did we learn?
    contexts: list(Context.t),
    total_time: Duration.t,
    exclusive_time: Duration.t,
    metrics: MetricSet.t,
    hostname: String.t,
    score: number(),
  }

  @spec new(String.t, String.t, any, list(Context.t), Duration.t, Duration.t, MetricSet.t, String.t) :: t
  def new(queue_name, job_name, time, contexts, total_time, exclusive_time, metrics, hostname) do
    %__MODULE__{
      queue_name: queue_name,
      job_name: job_name,
      time: time,
      contexts: contexts,
      total_time: total_time,
      exclusive_time: exclusive_time,
      metrics: metrics,
      hostname: hostname,

      # TODO: Update the trace w/ the score?
      score: 0
    }
  end

  @spec from_tracked_request(any) :: t
  def from_tracked_request(tracked_request) do
    root_layer = tracked_request.root_layer

    duration = Layer.total_time(root_layer)
    job_name = root_layer.name
    queue_name = "default"
    time = DateTime.utc_now() |> DateTime.to_iso8601()
    hostname = ScoutApm.Utils.hostname()
    contexts = tracked_request.contexts
    metric_set = create_trace_metrics(
      root_layer,
      ScopeStack.new(),
      MetricSet.new(%{compare_desc: true, collapse_all: true}))

    new(
      queue_name,
      job_name,
      time,
      contexts,
      duration,
      duration, # exclusive time isn't used?
      metric_set,
      hostname
    )
  end

  defp create_trace_metrics(layer, scope_stack, %MetricSet{} = metric_set) do
    detail_metric = Metric.from_layer(layer, ScopeStack.current_scope(scope_stack))
    summary_metric = Metric.from_layer_as_summary(layer)

    new_scope_stack = ScopeStack.push_scope(scope_stack, layer)

    # Absorb each child recursively
    Enum.reduce(layer.children, metric_set, fn child, set -> create_trace_metrics(child, new_scope_stack, set) end)
    # Then absorb this layer's 2 metrics
    |> MetricSet.absorb(detail_metric)
    |> MetricSet.absorb(summary_metric)
  end

  #####################
  #  Scoring a trace  #
  #####################

  @point_multiplier_speed 0.25
  @point_multiplier_percentile 1.0

  def as_scored_item(%__MODULE__{} = trace) do
    {{:score, score(trace), score_key(trace)}, trace}
  end

  # TODO: Re-add the queue name to the trace key
  defp score_key(%__MODULE__{} = trace) do
    "Job/" <> trace.job_name
  end

  def score(%__MODULE__{} = trace) do
    duration_score(trace) + percentile_score(trace)
  end

  defp duration_score(%__MODULE__{} = trace) do
    :math.log(1 + Duration.as(trace.total_time, :seconds)) * @point_multiplier_speed
  end

  defp percentile_score(%__MODULE__{} = trace) do
    with {:ok, percentile} <- ScoutApm.PersistentHistogram.percentile_for_value(
                                score_key(trace),
                                Duration.as(trace.total_time, :seconds))
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
        ScoutApm.Logger.debug("Failed to get percentile_score, error: #{err}")
        0
    end
  end
end
