# TODO: This should keep track of the stack of layers we're starting &
# stopping, and allow registered layers to scope themselves correctly to an
# outer controller layer.o
#
# Alternately - this could not scope anything, and then fixup the tree of
# layers after, before storing it off.

defmodule ScoutApm.TrackedRequest do
  import Logger

  ###############
  #  Interface  #
  ###############
  def start_layer(type, name \\ nil) do
    Logger.info("Starting layer of type: #{type} with name: #{name}")
    start_time = System.monotonic_time(:microseconds)
    push_layer(%{start_time: start_time, type: type, name: name})
    # TODO: set a "current_scope" if it's a Controller layer?
  end

  def stop_layer(name \\ nil) do
    layer = pop_layer()

    stop_time = System.monotonic_time(:microseconds)
    time_elapsed = (stop_time - layer.start_time) / 1_000_000

    resolved_type = layer.type
    resolved_name = name || layer.name
    scope = %{} # TODO: Determine if this should have a scope.

    ScoutApm.Worker.register_layer(
      resolved_type,
      resolved_name,
      time_elapsed,
      scope
    )

    Logger.info("Stopping layer of type: #{resolved_type} with name: #{resolved_name}")
  end

  # Immediately store the details passed, without going through start/stop
  def store_layer(type, name, time) do
    scope = %{type: current_layer().type, name: current_layer().name}

    ScoutApm.Worker.register_layer(
      type,
      name,
      time,
      scope
    )
    Logger.info("Stored a layer of type: #{type} with name: #{name}, time: #{time}, scope: #{inspect scope}")
  end

  ###########################
  #  Constructors & Lookup  #
  ###########################

  defp new() do
    save(%{
      layers: []
    })
  end

  defp lookup() do
    Process.get(:scout_apm_request) || new()
  end

  defp save(tracked_request) do
    Process.put(:scout_apm_request, tracked_request)
    tracked_request
  end

  defp layers() do
    lookup()
    |> Map.get(:layers)
  end

  defp current_layer() do
    layers()
    |> List.first
  end

  defp push_layer(l) do
    lookup()
    |> Map.update!(:layers, fn ls -> [l | ls] end)
    |> save()
  end

  defp pop_layer() do
    state = lookup()
    {cur_layer, new_state} =
      Map.get_and_update(state, :layers,
                         fn [cur | rest] -> {cur, rest} end)
    save(new_state)
    cur_layer
  end
end
