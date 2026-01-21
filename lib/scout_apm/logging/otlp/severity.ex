defmodule ScoutApm.Logging.OTLP.Severity do
  @moduledoc """
  Maps Elixir Logger levels to OpenTelemetry severity numbers and text.

  OTLP Severity Numbers (from OpenTelemetry specification):
  - 1-4:   TRACE
  - 5-8:   DEBUG
  - 9-12:  INFO
  - 13-16: WARN
  - 17-20: ERROR
  - 21-24: FATAL
  """

  @type level ::
          :emergency | :alert | :critical | :error | :warning | :warn | :notice | :info | :debug

  @doc """
  Converts an Elixir Logger level to an OTLP severity number.
  """
  @spec to_number(level()) :: pos_integer()
  def to_number(:emergency), do: 21
  def to_number(:alert), do: 21
  def to_number(:critical), do: 21
  def to_number(:error), do: 17
  def to_number(:warning), do: 13
  def to_number(:warn), do: 13
  def to_number(:notice), do: 11
  def to_number(:info), do: 9
  def to_number(:debug), do: 5
  def to_number(_), do: 0

  @doc """
  Converts an Elixir Logger level to an OTLP severity text string.
  """
  @spec to_text(level()) :: String.t()
  def to_text(:emergency), do: "FATAL"
  def to_text(:alert), do: "FATAL"
  def to_text(:critical), do: "FATAL"
  def to_text(:error), do: "ERROR"
  def to_text(:warning), do: "WARN"
  def to_text(:warn), do: "WARN"
  def to_text(:notice), do: "INFO2"
  def to_text(:info), do: "INFO"
  def to_text(:debug), do: "DEBUG"
  def to_text(_), do: "UNSPECIFIED"

  @doc """
  Compares two log levels. Returns true if level1 is at or above level2.
  Used for filtering logs by minimum level.
  """
  @spec meets_level?(level(), level()) :: boolean()
  def meets_level?(level1, level2) do
    to_number(level1) >= to_number(level2)
  end

  @doc """
  Returns the list of all supported Elixir log levels in order of severity (highest first).
  """
  @spec levels() :: [level()]
  def levels do
    [:emergency, :alert, :critical, :error, :warning, :notice, :info, :debug]
  end
end
