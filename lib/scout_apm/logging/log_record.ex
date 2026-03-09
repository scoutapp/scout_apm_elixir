defmodule ScoutApm.Logging.LogRecord do
  @moduledoc """
  Internal struct representing a log record to be sent via OTLP.

  Captures all relevant information from an Elixir Logger event
  and Scout APM context for export to an OTLP collector.
  """

  @type t :: %__MODULE__{
          timestamp_nanos: pos_integer(),
          observed_timestamp_nanos: pos_integer(),
          severity: atom(),
          message: String.t(),
          attributes: map(),
          trace_id: String.t() | nil,
          span_id: String.t() | nil,
          source_location: map() | nil,
          dropped_attributes_count: non_neg_integer()
        }

  defstruct [
    :timestamp_nanos,
    :observed_timestamp_nanos,
    :severity,
    :message,
    :attributes,
    :trace_id,
    :span_id,
    :source_location,
    dropped_attributes_count: 0
  ]

  @max_attributes 128
  @max_message_length 32_768

  @doc """
  Creates a new LogRecord from an Erlang :logger event.
  """
  @spec from_logger_event(map(), keyword()) :: t()
  def from_logger_event(event, scout_context \\ []) do
    now_nanos = System.system_time(:nanosecond)

    # Extract timestamp from event or use current time
    timestamp_nanos = extract_timestamp(event)

    # Extract severity level
    severity = Map.get(event, :level, :info)

    # Format the message
    message = format_message(event)

    # Build attributes from metadata and Scout context
    {attributes, dropped_count} = build_attributes(event, scout_context)

    # Extract source location if available
    source_location = extract_source_location(event)

    %__MODULE__{
      timestamp_nanos: timestamp_nanos,
      observed_timestamp_nanos: now_nanos,
      severity: severity,
      message: message,
      attributes: attributes,
      trace_id: Keyword.get(scout_context, :trace_id),
      span_id: Keyword.get(scout_context, :span_id),
      source_location: source_location,
      dropped_attributes_count: dropped_count
    }
  end

  @doc """
  Creates a LogRecord from simple parameters (for testing or direct use).
  """
  @spec new(atom(), String.t(), map()) :: t()
  def new(severity, message, attributes \\ %{}) do
    now_nanos = System.system_time(:nanosecond)
    {limited_attrs, dropped_count} = limit_attributes(attributes)

    %__MODULE__{
      timestamp_nanos: now_nanos,
      observed_timestamp_nanos: now_nanos,
      severity: severity,
      message: truncate_message(message),
      attributes: limited_attrs,
      dropped_attributes_count: dropped_count
    }
  end

  # Private functions

  defp extract_timestamp(%{meta: %{time: time}}) when is_integer(time) do
    # Erlang logger time is in microseconds
    time * 1000
  end

  defp extract_timestamp(_event) do
    System.system_time(:nanosecond)
  end

  defp format_message(%{msg: {:string, msg}}) when is_list(msg) do
    msg |> IO.iodata_to_binary() |> truncate_message()
  end

  defp format_message(%{msg: {:string, msg}}) when is_binary(msg) do
    truncate_message(msg)
  end

  defp format_message(%{msg: {:report, report}}) do
    report |> inspect(limit: 500) |> truncate_message()
  end

  defp format_message(%{msg: {format, args}}) when is_list(args) do
    try do
      :io_lib.format(format, args) |> IO.iodata_to_binary() |> truncate_message()
    rescue
      _ -> inspect({format, args}) |> truncate_message()
    end
  end

  defp format_message(_event) do
    ""
  end

  defp truncate_message(msg) when byte_size(msg) > @max_message_length do
    String.slice(msg, 0, @max_message_length - 3) <> "..."
  end

  defp truncate_message(msg), do: msg

  defp build_attributes(event, scout_context) do
    # Start with metadata from the log event
    metadata_attrs = extract_metadata(event)

    # Add Scout context
    scout_attrs =
      scout_context
      |> Keyword.drop([:trace_id, :span_id])
      |> Enum.into(%{})

    # Add source location as attributes
    source_attrs = extract_source_attrs(event)

    # Merge all attributes
    all_attrs =
      metadata_attrs
      |> Map.merge(scout_attrs)
      |> Map.merge(source_attrs)

    limit_attributes(all_attrs)
  end

  defp extract_metadata(%{meta: meta}) when is_map(meta) do
    # Filter out internal logger metadata
    internal_keys = [:time, :gl, :pid, :file, :line, :mfa, :domain, :error_logger]

    meta
    |> Map.drop(internal_keys)
    |> Enum.map(fn {k, v} -> {to_string(k), safe_value(v)} end)
    |> Enum.into(%{})
  end

  defp extract_metadata(_), do: %{}

  defp extract_source_attrs(%{meta: %{file: file, line: line, mfa: {mod, fun, arity}}}) do
    %{
      "code.filepath" => safe_string(file),
      "code.lineno" => line,
      "code.function" => "#{inspect(mod)}.#{fun}/#{arity}"
    }
  end

  defp extract_source_attrs(%{meta: %{file: file, line: line}}) do
    %{
      "code.filepath" => safe_string(file),
      "code.lineno" => line
    }
  end

  defp extract_source_attrs(_), do: %{}

  defp extract_source_location(%{meta: %{file: file, line: line, mfa: {mod, fun, arity}}}) do
    %{
      "file" => safe_string(file),
      "line" => line,
      "function" => "#{inspect(mod)}.#{fun}/#{arity}"
    }
  end

  defp extract_source_location(%{meta: %{file: file, line: line}}) do
    %{
      "file" => safe_string(file),
      "line" => line
    }
  end

  defp extract_source_location(_), do: nil

  defp safe_string(value) when is_list(value), do: List.to_string(value)
  defp safe_string(value) when is_binary(value), do: value
  defp safe_string(value), do: inspect(value)

  defp safe_value(value) when is_binary(value), do: value
  defp safe_value(value) when is_number(value), do: value
  defp safe_value(value) when is_boolean(value), do: value
  defp safe_value(value) when is_atom(value), do: Atom.to_string(value)
  defp safe_value(value) when is_list(value), do: Enum.map(value, &safe_value/1)

  defp safe_value(value) when is_map(value) do
    value
    |> Enum.map(fn {k, v} -> {to_string(k), safe_value(v)} end)
    |> Enum.into(%{})
  end

  defp safe_value(value), do: inspect(value, limit: 100)

  defp limit_attributes(attrs) when map_size(attrs) <= @max_attributes do
    {attrs, 0}
  end

  defp limit_attributes(attrs) do
    dropped = map_size(attrs) - @max_attributes

    limited =
      attrs
      |> Enum.take(@max_attributes)
      |> Enum.into(%{})

    {limited, dropped}
  end
end
