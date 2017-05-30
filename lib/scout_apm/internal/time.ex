defmodule ScoutApm.Internal.Time do
  @moduledoc false

  # A set of utilities to abstract away the mechanisms of how we
  # determine Time related things.  Timex changed drastically between
  # versions, and we're at the mercy of other transient dependnecies on
  # which version we get, so we can't use that dependency.
  #
  # Elixir itself introduced NaiveDateTime in 1.4, but 1.3 doesn't have it.
  #
  # So this is a set of functions which wrap erlang's calendar
  # functions, and change them into scout-specific versions for exactly
  # what we need.

  @opaque t :: integer
  @type scale :: :nanoseconds | :microseconds | :milliseconds | :seconds

  @spec now() :: t
  def now() do
    System.system_time(:nanoseconds)
  end

  @spec diff(t, t) :: number
  def diff(t1, t2), do: diff(t1, t2, :nanoseconds)

  @spec diff(t, t, scale) :: number
  def diff(t1, t2, :nanoseconds), do: t1 - t2
  def diff(t1, t2, :microseconds), do: (t1 - t2) / 1_000
  def diff(t1, t2, :milliseconds), do: (t1 - t2) / 1_000_000
  def diff(t1, t2, :seconds), do: (t1 - t2) / 1_000_000_000

  # TODO: Erlang doesn't seem to have any built-in for turning a calendar into iso8601?
  @spec iso8601(t) :: String.t
  def iso8601(t) do
    posix_to_calendar(t)
  end

  defp posix_to_calendar(t) do
    base = :calendar.datetime_to_gregorian_seconds({{1970, 1, 1}, {0, 0, 0}})
    seconds_since_posix = base + (t / 1_000_000_000)
    :calendar.gregorian_seconds_to_datetime(seconds_since_posix)
  end
end
