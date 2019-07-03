defmodule ScoutApm.Internal.DbMetric do
  @moduledoc """
  Store a single metric, that may contain aggregated data around many calls to that metric.
  Uniquely identified by type / name / desc / scope
  """

  alias ScoutApm.Internal.{Duration, DbMetric}

  @type t :: %__MODULE__{
          model_name: String.t(),
          operation: String.t(),
          scope: String.t(),
          transaction_count: non_neg_integer(),
          call_count: non_neg_integer(),
          call_time: Duration.t(),
          rows_returned: non_neg_integer(),
          min_call_time: Duration.t(),
          max_call_time: Duration.t(),
          min_rows_returned: non_neg_integer(),
          max_rows_returned: non_neg_integer(),
          histogram: term()
        }

  # If we can't name the model, default to:
  @default_model "SQL"

  # If we can't name the operation, default to:
  @default_operation "other"

  defstruct [
    :scope,
    :transaction_count,
    :call_time,
    :min_call_time,
    :max_call_time,
    :min_rows_returned,
    :max_rows_returned,
    :histogram,
    call_count: 0,
    rows_returned: 0,
    model_name: @default_model,
    operation: @default_operation
  ]

  def new do
    %__MODULE__{
      call_count: 0,
      rows_returned: 0,
      model_name: @default_model,
      operation: @default_operation,
      histogram: ApproximateHistogram.new()
    }
  end

  @spec key(t()) :: String.t()
  def key(%DbMetric{} = db_metric) do
    "#{db_metric.model_name}-#{db_metric.operation}-#{db_metric.scope}"
  end

  @spec combine(t(), t()) :: t()
  def combine(db_metric, other_db_metric) do
    %{
      db_metric
      | transaction_count: db_metric.transaction_count + other_db_metric.transaction_count,
        call_count: db_metric.call_count + other_db_metric.call_count,
        rows_returned: db_metric.rows_returned + other_db_metric.rows_returned,
        call_time: Duration.add(db_metric.call_time, other_db_metric.call_time),
        min_call_time: minimum_duration(db_metric.min_call_time, other_db_metric.call_time),
        max_call_time: maximum_duration(db_metric.max_call_time, other_db_metric.call_time),
        min_rows_returned: minimum(db_metric.min_rows_returned, other_db_metric.rows_returned),
        max_rows_returned: maximum(db_metric.max_rows_returned, other_db_metric.rows_returned),
        histogram: combine_histogram(db_metric, other_db_metric)
    }
  end

  defp minimum(nil, new_value), do: new_value
  defp minimum(current_value, new_value) when new_value < current_value, do: new_value
  defp minimum(current_value, _new_value), do: current_value

  defp maximum(nil, new_value), do: new_value
  defp maximum(current_value, new_value) when new_value > current_value, do: new_value
  defp maximum(current_value, _new_value), do: current_value

  defp minimum_duration(nil, new_duration), do: new_duration

  defp minimum_duration(current_duration, new_duration) do
    Duration.min(current_duration, new_duration)
  end

  defp maximum_duration(nil, new_duration), do: new_duration

  defp maximum_duration(current_duration, new_duration) do
    Duration.max(current_duration, new_duration)
  end

  defp combine_histogram(%{histogram: nil}, %{call_time: call_time}) do
    ApproximateHistogram.new()
    |> ApproximateHistogram.add(call_time.value)
  end

  defp combine_histogram(%{histogram: %ApproximateHistogram{} = histogram}, %{
         call_time: call_time
       }) do
    ApproximateHistogram.add(histogram, call_time.value)
  end
end
