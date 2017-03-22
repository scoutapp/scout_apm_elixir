defmodule ScoutApm.Internal.Metric do
  alias ScoutApm.Internal.Layer

  defstruct [
    :type,
    :name,

    # scope should be a 
    :scope,

    :call_count,

    # If call count is > 1, the times should be the sum.
    :total_time,
    :exclusive_time,
  ]

  ##################
  #  Construction  #
  ##################

  # Layers don't know their own scope, so you need to pass it in explicitly.
  def from_layer(%Layer{} = layer, scope) do
    %__MODULE__{
      call_count: 1,
      type: layer.type,
      name: layer.name,
      total_time: Layer.total_time(layer),
      exclusive_time: Layer.total_exclusive_time(layer),
      scope: scope,
    }
  end

  #######################
  #  Updater Functions  #
  #######################

  #############
  #  Queries  #
  #############

end
