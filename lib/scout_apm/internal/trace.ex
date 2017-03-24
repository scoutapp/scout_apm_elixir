defmodule ScoutApm.Internal.Trace do
  @moduledoc """
  A record of a single trace.
  """

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
end
