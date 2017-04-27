defmodule ScoutApm.Internal.Trace do
  @moduledoc """
  A record of a single trace.
  """

  alias ScoutApm.Internal.Duration

  defstruct [
    :type,
    :name,
    :total_call_time,
    :metrics, # A metric set? Needs to distinguish between different `desc` fields
    :uri,
    :context,
    :time,
    :hostname, # hack - we need to reset these server side.
    :score,
  ]

  def new(type, name, duration, metrics, uri, context, time, hostname) do
    %__MODULE__{
      type: type,
      name: name,
      total_call_time: duration,
      metrics: metrics,
      uri: uri,
      context: context,
      time: time,
      hostname: hostname,
    }
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
      _ -> 0
    end
  end
end
