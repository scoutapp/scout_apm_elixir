defmodule ScoutApm.Logging.OTLP.Encoder do
  @moduledoc """
  Encodes log records into OTLP JSON format.

  Builds the full OTLP structure:
  {
    "resourceLogs": [{
      "resource": { "attributes": [...] },
      "scopeLogs": [{
        "scope": { "name": "scout_apm_elixir", "version": "..." },
        "logRecords": [...]
      }]
    }]
  }
  """

  alias ScoutApm.Logging.OTLP.{Resource, Severity}
  alias ScoutApm.Logging.LogRecord

  @scope_name "scout_apm_elixir"

  @doc """
  Encodes a list of LogRecord structs into OTLP JSON format.
  """
  @spec encode([LogRecord.t()]) :: map()
  def encode(log_records) when is_list(log_records) do
    %{
      "resourceLogs" => [
        %{
          "resource" => %{
            "attributes" => Resource.build()
          },
          "scopeLogs" => [
            %{
              "scope" => build_scope(),
              "logRecords" => Enum.map(log_records, &encode_log_record/1)
            }
          ]
        }
      ]
    }
  end

  @doc """
  Encodes a single LogRecord struct into OTLP format.
  """
  @spec encode_log_record(LogRecord.t()) :: map()
  def encode_log_record(%LogRecord{} = record) do
    base = %{
      "timeUnixNano" => to_string(record.timestamp_nanos),
      "observedTimeUnixNano" => to_string(record.observed_timestamp_nanos),
      "severityNumber" => Severity.to_number(record.severity),
      "severityText" => Severity.to_text(record.severity),
      "body" => encode_body(record.message)
    }

    base
    |> maybe_add_attributes(record.attributes)
    |> maybe_add_trace_context(record)
    |> maybe_add_dropped_count(record.dropped_attributes_count)
  end

  # Private functions

  defp build_scope do
    %{
      "name" => @scope_name,
      "version" => get_version()
    }
  end

  defp get_version do
    case :application.get_key(:scout_apm, :vsn) do
      {:ok, vsn} -> List.to_string(vsn)
      _ -> "unknown"
    end
  end

  defp encode_body(message) when is_binary(message) do
    %{"stringValue" => message}
  end

  defp encode_body(message) do
    %{"stringValue" => inspect(message)}
  end

  defp maybe_add_attributes(map, nil), do: map
  defp maybe_add_attributes(map, attributes) when map_size(attributes) == 0, do: map

  defp maybe_add_attributes(map, attributes) do
    encoded_attrs =
      attributes
      |> Enum.map(&encode_attribute/1)
      |> Enum.reject(&is_nil/1)

    if length(encoded_attrs) > 0 do
      Map.put(map, "attributes", encoded_attrs)
    else
      map
    end
  end

  defp encode_attribute({key, value}) when is_binary(key) do
    encode_attribute_value(key, value)
  end

  defp encode_attribute({key, value}) when is_atom(key) do
    encode_attribute_value(Atom.to_string(key), value)
  end

  defp encode_attribute(_), do: nil

  defp encode_attribute_value(key, value) when is_binary(value) do
    %{"key" => key, "value" => %{"stringValue" => value}}
  end

  defp encode_attribute_value(key, value) when is_integer(value) do
    %{"key" => key, "value" => %{"intValue" => to_string(value)}}
  end

  defp encode_attribute_value(key, value) when is_float(value) do
    %{"key" => key, "value" => %{"doubleValue" => value}}
  end

  defp encode_attribute_value(key, value) when is_boolean(value) do
    %{"key" => key, "value" => %{"boolValue" => value}}
  end

  defp encode_attribute_value(key, value) when is_atom(value) do
    %{"key" => key, "value" => %{"stringValue" => Atom.to_string(value)}}
  end

  defp encode_attribute_value(key, value) when is_list(value) do
    # Encode as array value
    encoded_values =
      value
      |> Enum.map(&encode_array_value/1)
      |> Enum.reject(&is_nil/1)

    %{"key" => key, "value" => %{"arrayValue" => %{"values" => encoded_values}}}
  end

  defp encode_attribute_value(key, value) when is_map(value) do
    # Encode map as JSON string for simplicity
    case Jason.encode(value) do
      {:ok, json} -> %{"key" => key, "value" => %{"stringValue" => json}}
      _ -> %{"key" => key, "value" => %{"stringValue" => inspect(value)}}
    end
  end

  defp encode_attribute_value(key, value) do
    %{"key" => key, "value" => %{"stringValue" => inspect(value)}}
  end

  defp encode_array_value(value) when is_binary(value), do: %{"stringValue" => value}
  defp encode_array_value(value) when is_integer(value), do: %{"intValue" => to_string(value)}
  defp encode_array_value(value) when is_float(value), do: %{"doubleValue" => value}
  defp encode_array_value(value) when is_boolean(value), do: %{"boolValue" => value}

  defp encode_array_value(value) when is_atom(value),
    do: %{"stringValue" => Atom.to_string(value)}

  defp encode_array_value(value), do: %{"stringValue" => inspect(value)}

  defp maybe_add_trace_context(map, %LogRecord{trace_id: nil}), do: map
  defp maybe_add_trace_context(map, %LogRecord{span_id: nil}), do: map

  defp maybe_add_trace_context(map, %LogRecord{trace_id: trace_id, span_id: span_id}) do
    map
    |> Map.put("traceId", encode_trace_id(trace_id))
    |> Map.put("spanId", encode_span_id(span_id))
  end

  defp encode_trace_id(trace_id) when is_binary(trace_id), do: trace_id

  defp encode_trace_id(trace_id) when is_integer(trace_id) do
    trace_id
    |> Integer.to_string(16)
    |> String.downcase()
    |> String.pad_leading(32, "0")
  end

  defp encode_span_id(span_id) when is_binary(span_id), do: span_id

  defp encode_span_id(span_id) when is_integer(span_id) do
    span_id
    |> Integer.to_string(16)
    |> String.downcase()
    |> String.pad_leading(16, "0")
  end

  defp maybe_add_dropped_count(map, nil), do: map
  defp maybe_add_dropped_count(map, 0), do: map

  defp maybe_add_dropped_count(map, count) do
    Map.put(map, "droppedAttributesCount", count)
  end
end
