defmodule ScoutApm.DirectAnalysisStore do
  alias ScoutApm.Internal.WebTrace
  alias ScoutApm.Payload.SlowTransaction

  @trace_key :tracked_request

  def record(tracked_request) do
    Process.put(@trace_key, tracked_request)
  end

  def get_tracked_request do
    Process.get(@trace_key)
  end

  def payload do
    Map.merge(transaction(), %{metadata: metadata()})
  end

  def transaction do
    if get_tracked_request() do
      get_tracked_request() |> WebTrace.from_tracked_request() |> SlowTransaction.new()
    else
      %{}
    end
  end

  def metadata do
    ScoutApm.Payload.Metadata.new(NaiveDateTime.utc_now())
  end

  def encode(nil), do: Jason.encode!(%{})
  def encode(payload), do: Jason.encode!(payload)
end
