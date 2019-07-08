defmodule ScoutApm.Internal.Layer do
  @moduledoc """
  Internal to the ScoutAPM agent.

  Represents a single layer during a TrackedRequest
  """

  @type t :: %__MODULE__{
          type: String.t(),
          name: nil | String.t(),
          desc: nil | String.t(),
          backtrace: nil | list(any()),
          uri: nil | String.t(),
          started_at: number(),
          stopped_at: nil | Integer,
          scopable: boolean,
          manual_duration: nil | ScoutApm.Internal.Duration.t(),
          children: list(%__MODULE__{})
        }

  defstruct [
    :type,
    :name,
    :desc,
    :backtrace,
    :uri,
    :started_at,
    :stopped_at,

    # If this is set, ignore started_at -> stopped_at valuse when calculating
    # how long this layer ran
    :manual_duration,
    scopable: true,
    children: []
  ]

  alias ScoutApm.Internal.Duration

  ##################
  #  Construction  #
  ##################

  @spec new(map) :: __MODULE__.t()
  def new(%{type: type, opts: opts} = data) do
    started_at = data[:started_at] || NaiveDateTime.utc_now()
    name = data[:name]
    scopable = Keyword.get(opts, :scopable, true)

    %__MODULE__{
      type: type,
      name: name,
      started_at: started_at,
      scopable: scopable
    }
  end

  #######################
  #  Updater Functions  #
  #######################

  # Don't update a name to become nil
  def update_name(layer, nil), do: layer
  def update_name(layer, name), do: %{layer | name: name}

  def update_stopped_at(layer), do: update_stopped_at(layer, NaiveDateTime.utc_now())

  def update_stopped_at(layer, stopped_at) do
    %{layer | stopped_at: stopped_at}
  end

  def update_children(layer, children) do
    %{layer | children: children}
  end

  def update_desc(layer, desc) do
    %{layer | desc: desc}
  end

  def update_backtrace(layer, backtrace) do
    %{layer | backtrace: backtrace}
  end

  def update_uri(layer, uri) do
    %{layer | uri: uri}
  end

  def set_manual_duration(layer, %Duration{} = duration) do
    %{layer | manual_duration: duration}
  end

  ##################
  #  Update Fields #
  ##################

  # Updates Layer fields in bulk. See `update_field` functions for fields that permit updates.
  def update_fields(layer, []), do: layer

  def update_fields(layer, fields) do
    Enum.reduce(fields, layer, fn {key, value}, layer ->
      update_field(layer, key, value)
    end)
  end

  defp update_field(layer, :desc, value), do: update_desc(layer, value)
  defp update_field(layer, :backtrace, value), do: update_backtrace(layer, value)

  #############
  #  Queries  #
  #############

  def total_time(layer) do
    case layer.manual_duration do
      nil ->
        NaiveDateTime.diff(layer.stopped_at, layer.started_at, :microsecond)
        |> Duration.new(:microseconds)

      %Duration{} ->
        layer.manual_duration
    end
  end

  def total_child_time(layer) do
    Enum.reduce(layer.children, Duration.zero(), fn child, acc ->
      Duration.add(acc, total_time(child))
    end)
  end

  def total_exclusive_time(layer) do
    Duration.subtract(total_time(layer), total_child_time(layer))
  end
end
