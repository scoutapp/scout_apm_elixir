defmodule ScoutApm.TrackedRequest do
  @moduledoc """
  Stores information about a single request, as the request is happening.
  Attempts to do minimal processing. Its job is only to collect up information.
  Once the request is finished, the last layer will be stopped - and we can
  send this whole data structure off to be processed.

  A quick visual of how this looks:

  START Controller (this is scope.)
    TRACK Ecto

    START View
      TRACK Ecto

      START Partial View
      STOP Partial View
    STOP View
  STOP Controller
  """

  alias ScoutApm.Internal.Layer

  defstruct [:root_layer, :layers, :children, :contexts, :collector_fn, :error, :ignored, :ignoring_depth]

  ###############
  #  Interface  #
  ###############

  def start_layer(%__MODULE__{ignored: true} = tr, _type, _name, _opts) do
    %{tr | ignoring_depth: tr.ignoring_depth + 1}
  end

  def start_layer(%__MODULE__{} = tr, type, name, opts) do
    layer = Layer.new(%{type: type, name: name, opts: opts || []})
    push_layer(tr, layer)
  end

  def start_layer(type, name, opts \\ []) do
    with_saved_tracked_request(fn tr -> start_layer(tr, type, name, opts) end)
  end

  def stop_layer() do
    stop_layer(fn x -> x end)
  end

  def stop_layer(callback) when is_function(callback) do
    with_saved_tracked_request(fn tr -> stop_layer(tr, callback) end)
  end

  def stop_layer(%__MODULE__{ignored: true} = tr) do
    if tr.ignoring_depth == 1 do
      # clear tracked request when last layer is stopped
      nil
    else
      %{tr | ignoring_depth: tr.ignoring_depth - 1}
    end
  end

  def stop_layer(%__MODULE__{} = tr) do
    stop_layer(tr, fn x -> x end)
  end

  def stop_layer(%__MODULE__{layers: []} = tracked_request, callback) when is_function(callback) do
    ScoutApm.Logger.log(:info, "Scout Layer mismatch when stopping layer in #{inspect(tracked_request)}")
    :error
  end

  def stop_layer(%__MODULE__{children: []} = tracked_request, callback) when is_function(callback) do
    ScoutApm.Logger.log(:info, "Scout Layer mismatch when stopping layer in #{inspect(tracked_request)}")
    :error
  end

  def stop_layer(%__MODULE__{} = tr, callback) when is_function(callback) do
    {popped_layer, tr1} = pop_layer(tr)

    updated_layer =
      popped_layer
      |> Layer.update_stopped_at
      |> callback.()

    tr2 =
      tr1
      |> record_child_of_current_layer(updated_layer)

    # We finished tracing this request, so go and record it.
    if Enum.count(layers(tr2)) == 0 do
      request = tr2 |> with_root_layer(updated_layer)
      request.collector_fn.(request)
      nil
    else
      tr2
    end
  end

  def track_layer(%__MODULE__{} = tr, type, name, duration, fields, callback) do
    layer =
      Layer.new(%{type: type, name: name, opts: []})
      |> Layer.update_stopped_at
      |> Layer.set_manual_duration(duration)
      |> Layer.update_fields(fields)
      |> callback.()

    record_child_of_current_layer(tr, layer)
  end

  def track_layer(type, name, duration, fields, callback \\ (fn x -> x end)) do
    with_saved_tracked_request(fn tr -> track_layer(tr, type, name, duration, fields, callback) end)
  end

  def ignore() do
    with_saved_tracked_request(fn tr ->
      %{tr |
        ignored: true,
        ignoring_depth: Enum.count(tr.layers),
        layers: [],
        root_layer: nil,
      }
    end)
  end

  def record_context(%__MODULE__{} = tr, %ScoutApm.Internal.Context{} = context),
    do: %{tr | contexts: [context | tr.contexts]}
  def record_context(%ScoutApm.Internal.Context{} = context),
    do: with_saved_tracked_request(fn tr -> record_context(tr, context) end)

  @doc """
  Not intended for public use. Applies a function that takes an Layer, and
  returns a Layer to the currently tracked layer. Building block for things
  like: "update_desc"
  """
  def update_current_layer(%__MODULE__{} = tr, fun) when is_function(fun) do
    [current | rest] = layers(tr)
    new = fun.(current)
    Map.put(tr, :layers, [new | rest])
  end

  def update_current_layer(fun) when is_function(fun) do
    with_saved_tracked_request(fn tr -> update_current_layer(tr, fun) end)
  end

  #################################
  #  Constructors & Manipulation  #
  #################################

  def new(custom_collector \\ nil) do
    save(%__MODULE__{
      root_layer: nil,
      layers: [],
      ignored: false,
      children: [],
      contexts: [],
      collector_fn: build_collector_fn(custom_collector),
    })
  end

  def mark_error() do
    with_saved_tracked_request(fn(request) ->
      mark_error(request)
    end)
  end

  def mark_error(%__MODULE__{} = request) do
    %{request | error: true}
  end

  defp build_collector_fn(f) when is_function(f), do: f
  defp build_collector_fn({module, fun}), do: fn request -> apply(module, fun, [request]) end
  defp build_collector_fn(_), do: fn request ->
    ScoutApm.Collector.record_async(request)
    ScoutApm.DirectAnalysisStore.record(request)
  end

  def change_collector_fn(f), do: lookup() |> change_collector_fn(f) |> save()
  def change_collector_fn(%__MODULE__{} = tr, f) do
    %{tr | collector_fn: build_collector_fn(f)}
  end

  defp lookup() do
    Process.get(:scout_apm_request) || new()
  end

  defp save(nil) do
    Process.delete(:scout_apm_request)
    nil
  end

  defp save(:error) do
    Process.delete(:scout_apm_request)
    nil
  end

  defp save(%__MODULE__{} = tr) do
    Process.put(:scout_apm_request, tr)
    tr
  end

  defp with_saved_tracked_request(f) when is_function(f) do
    lookup()
    |> f.()
    |> save()
  end


  defp layers(%__MODULE__{} = tr) do
    tr
    |> Map.get(:layers)
  end

  defp with_root_layer(%__MODULE__{} = tr, layer) do
    tr
    |> Map.update!(:root_layer,
                   fn nil -> layer
                      rl -> rl
                   end)
  end

  defp push_layer(%__MODULE__{} = tr, l) do
    tr

    # Track the layer itself
    |> Map.update!(:layers, fn ls -> [l | ls] end)

    # Push a new children tracking layer
    |> Map.update!(:children, fn cs -> [[] | cs] end)
  end

  # Pop this layer off the layer stack
  # Pop the children recorded for this layer
  # Attach the children to the layer
  # - note, we can't save this layer into its parent's children array yet, since it will get further edited in stop_layer
  # Return the layer
  defp pop_layer(%__MODULE__{} = tr) do
    s0 = tr
    {cur_layer, s1} =
      Map.get_and_update(s0, :layers,
                         fn [cur | rest] -> {cur, rest} end)

    {children, new_tr} =
      Map.get_and_update(s1, :children,
                         fn [cur | rest] -> {cur, rest} end)

    popped_layer =
      cur_layer
      |> Layer.update_children(Enum.reverse(children))

    {popped_layer, new_tr}
  end

  # Inserts a child layer into the children array for its parent. Should be
  # called after pop_layer() has been called, so that the child list at the
  # head is for its parent.
  defp record_child_of_current_layer(%__MODULE__{} = tr, child) do
    tr
    |> Map.update!(:children, fn
        [layer_children | cs] -> [[child | layer_children] | cs]
        [] -> []
      end)
  end
end
