# Stores information about a single request, as the request is happening.
# Attempts to do minimal processing. Its job is only to collect up information.
# Once the request is finished, the last layer will be stopped - and we can
# send this whole data structure off to be processed in another worker.
#
# START Controller (this is scope.)
#   START Ecto (got it!)
#   STOP Ecto
# 
#   START View
#     START Partial View
#     STOP Partial View
#   STOP View
# STOP Controller

defmodule ScoutApm.TrackedRequest do
  require Logger

  alias ScoutApm.Internal.Layer

  ###############
  #  Interface  #
  ###############

  def start_layer(type, name \\ nil) do
    Logger.info("Starting layer of type: #{type} with name: #{name}")
    push_layer(Layer.new(%{type: type, name: name}))
  end

  def stop_layer(name \\ nil, callback \\ (fn x -> x end)) do
    layer = pop_layer()
            |> Layer.update_stopped_at
            |> Layer.update_name(name)
            |> callback.()

    record_child_of_current_layer(layer)

    # We finished tracing this request, so go and record it.
    if Enum.count(layers()) == 0 do
      Logger.info("Recording Trace")
      ScoutApm.Collector.record_async(
        lookup() |> with_root_layer(layer)
      )
    end
  end

  #################################
  #  Constructors & Manipulation  #
  #################################

  defp new() do
    save(%{
      root_layer: nil,
      layers: [],
      children: [],
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

  def with_root_layer(tracked_request, l) do
    tracked_request
    |> Map.update!(:root_layer,
                   fn nil -> l
                      rl -> rl
                   end)
  end

  defp push_layer(l) do
    lookup()

    # Track the layer itself
    |> Map.update!(:layers, fn ls -> [l | ls] end)

    # Push a new children tracking layer
    |> Map.update!(:children, fn cs -> [[] | cs] end)
    |> save()
  end

  # Pop this layer off the layer stack
  # Pop the children recorded for this layer
  # Attach the children to the layer
  # - note, we can't save this layer into its parent's children array yet, since it will get further edited in stop_layer
  # Return the layer
  defp pop_layer() do
    s0 = lookup()
    {cur_layer, s1} =
      Map.get_and_update(s0, :layers,
                         fn [cur | rest] -> {cur, rest} end)

    {children, new_state} =
      Map.get_and_update(s1, :children,
                         fn [cur | rest] -> {cur, rest} end)

    save(new_state)

    cur_layer
    |> Layer.update_children(children)
  end

  # Inserts a child layer into the children array for its parent. Should be
  # called after pop_layer() has been called, so that the child list at the
  # head is for its parent.
  defp record_child_of_current_layer(child) do
    lookup()
    |> Map.update!(:children, fn
        [layer_children | cs] -> [[child | layer_children] | cs]
        [] -> []
      end)
    |> save()
  end

end
