defmodule ScoutApm.DevTrace.Store do
  alias ScoutApm.Internal.Trace
  alias ScoutApm.Payload.SlowTransaction
  require Logger

  @trace_key :tracked_request

  def record(tracked_request) do
    if ScoutApm.DevTrace.enabled?, do: Process.put(@trace_key, tracked_request)
  end

  def get_tracked_request do
    Process.get(@trace_key)
  end

  def payload do
    Map.merge(transaction(),%{metadata: metadata()})
  end

  def transaction do
    if get_tracked_request() do
      get_tracked_request() |> Trace.from_tracked_request |> SlowTransaction.new
    else
      %{}
    end
  end

  def metadata do
    ScoutApm.Payload.Metadata.new(NaiveDateTime.utc_now())
  end

  def encode(nil), do: Poison.encode!(%{})
  def encode(payload), do: Poison.encode!(payload)

end
