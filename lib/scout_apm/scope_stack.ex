defmodule ScoutApm.ScopeStack do
  @moduledoc """
  Internal to ScoutApm agent.

  Used as a helper to track the current scope a layer is under, as we
  build up a trace.

  This doesn't have any way to pop, since it's used in a recursive call,
  and coppies should just be tossed as the call stack finishes
  """

  alias ScoutApm.Internal.Layer

  @max_depth 2

  def new() do
    []
  end

  def push_scope(stack, %Layer{scopable: false}), do: stack
  def push_scope(stack, %Layer{} = layer), do: push_scope(stack, layer_to_scope(layer))

  def push_scope(stack, %{} = scope) do
    if Enum.count(stack) >= @max_depth do
      stack
    else
      [scope | stack]
    end
  end

  def layer_to_scope(%Layer{} = layer) do
    %{type: layer.type, name: layer.name}
  end

  def current_scope([scope | _]), do: scope
  def current_scope([]), do: nil
end
