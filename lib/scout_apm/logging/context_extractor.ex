defmodule ScoutApm.Logging.ContextExtractor do
  @moduledoc """
  Extracts Scout APM context from the current process for log enrichment.

  Reads from Process.get(:scout_apm_request) to extract:
  - scout_transaction_id - TrackedRequest.id
  - scout_start_time - Root layer start time (ISO 8601)
  - scout_end_time - Root layer end time (ISO 8601, if completed)
  - scout_duration - Request duration in seconds (if completed)
  - scout_current_operation - Current span's type/name
  - controller_entrypoint / job_entrypoint / custom_entrypoint - Entrypoint name
  - scout_tag_{key} - Custom tags from ScoutApm.Context
  - user.{key} - User context (excluding ip)
  - service.name - From config
  """

  alias ScoutApm.TrackedRequest
  alias ScoutApm.Internal.Context

  @doc """
  Extracts Scout APM context from the current process.
  Returns a list of {key, value} tuples suitable for log enrichment.
  """
  @spec extract() :: list({String.t(), any()})
  def extract do
    case Process.get(:scout_apm_request) do
      %TrackedRequest{} = tr ->
        extract_from_tracked_request(tr)

      _ ->
        base_context()
    end
  end

  @doc """
  Extracts context from a specific TrackedRequest struct.
  """
  @spec extract_from_tracked_request(TrackedRequest.t()) :: list({String.t(), any()})
  def extract_from_tracked_request(%TrackedRequest{} = tr) do
    base = base_context()

    request_context = [
      {"scout_transaction_id", tr.id}
    ]

    timing_context = extract_timing_context(tr)
    layer_context = extract_layer_context(tr)
    custom_context = extract_custom_context(tr.contexts)

    (base ++ request_context ++ timing_context ++ layer_context ++ custom_context)
    |> Enum.filter(fn {_k, v} -> v != nil end)
  end

  # Private functions

  defp base_context do
    service_name = ScoutApm.Config.find(:name)

    if service_name do
      [{"service.name", service_name}]
    else
      []
    end
  end

  defp extract_timing_context(%TrackedRequest{root_layer: nil}), do: []

  defp extract_timing_context(%TrackedRequest{root_layer: layer}) do
    start_attrs =
      if layer.started_at do
        [{"scout_start_time", NaiveDateTime.to_iso8601(layer.started_at) <> "Z"}]
      else
        []
      end

    end_attrs =
      if layer.stopped_at do
        duration =
          NaiveDateTime.diff(layer.stopped_at, layer.started_at, :microsecond) / 1_000_000

        [
          {"scout_end_time", NaiveDateTime.to_iso8601(layer.stopped_at) <> "Z"},
          {"scout_duration", duration}
        ]
      else
        []
      end

    start_attrs ++ end_attrs
  end

  defp extract_layer_context(%TrackedRequest{layers: layers, root_layer: root_layer})
       when is_list(layers) do
    # Determine the entrypoint layer (root or outermost active layer)
    entrypoint_layer =
      case {layers, root_layer} do
        {_, %{type: type} = rl} when type in ["Controller", "Job"] -> rl
        {[first | _], nil} -> first
        {[], nil} -> nil
        {_, rl} -> rl
      end

    # Current operation from active layer stack
    current_op =
      case layers do
        [current | _] ->
          [{"scout_current_operation", "#{current.type}/#{current.name}"}]

        [] ->
          []
      end

    entrypoint_attrs =
      case entrypoint_layer do
        nil -> []
        layer -> entrypoint_attribute(layer)
      end

    current_op ++ entrypoint_attrs
  end

  defp extract_layer_context(_), do: []

  defp entrypoint_attribute(%{type: "Controller", name: name}) when is_binary(name) do
    [{"controller_entrypoint", name}]
  end

  defp entrypoint_attribute(%{type: "Job", name: name}) when is_binary(name) do
    [{"job_entrypoint", name}]
  end

  defp entrypoint_attribute(%{type: type, name: name})
       when is_binary(type) and is_binary(name) do
    [{"custom_entrypoint", name}]
  end

  defp entrypoint_attribute(_), do: []

  defp extract_custom_context(nil), do: []
  defp extract_custom_context([]), do: []

  defp extract_custom_context(contexts) when is_list(contexts) do
    contexts
    |> Enum.map(&context_to_attribute/1)
    |> Enum.filter(fn {_k, v} -> v != nil end)
  end

  defp context_to_attribute(%Context{type: :extra, key: key, value: value}) do
    {"scout_tag_#{key}", safe_value(value)}
  end

  defp context_to_attribute(%Context{type: :user, key: "ip", value: _value}) do
    {nil, nil}
  end

  defp context_to_attribute(%Context{type: :user, key: key, value: value}) do
    {"user.#{key}", safe_value(value)}
  end

  defp context_to_attribute(_), do: {nil, nil}

  defp safe_value(value) when is_binary(value), do: value
  defp safe_value(value) when is_number(value), do: value
  defp safe_value(value) when is_boolean(value), do: value
  defp safe_value(value) when is_atom(value), do: Atom.to_string(value)
  defp safe_value(value), do: inspect(value, limit: 100)
end
