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

  require Logger

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
        base_context() ++ extract_from_logger_metadata()
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

  @doc """
  Stashes Scout context into Logger metadata so it survives TrackedRequest cleanup.

  Call this when a Controller or Job layer starts. The metadata persists on the
  process for the entire request lifetime, so logs emitted after TrackedRequest
  is cleaned up (e.g., Phoenix endpoint stop logs) still get Scout context.
  """
  @spec stash_context(String.t(), String.t()) :: :ok
  def stash_context(type, name) when is_binary(type) and is_binary(name) do
    {key, _} = entrypoint_key_value(type, name)

    transaction_id =
      case Process.get(:scout_apm_request) do
        %TrackedRequest{id: id} -> id
        _ -> nil
      end

    metadata =
      [scout_entrypoint_key: key, scout_entrypoint_name: name] ++
        if(transaction_id, do: [scout_transaction_id: transaction_id], else: [])

    Logger.metadata(metadata)

    :ok
  end

  # Private functions

  defp extract_from_logger_metadata do
    meta = Logger.metadata()
    key = meta[:scout_entrypoint_key]
    name = meta[:scout_entrypoint_name]
    transaction_id = meta[:scout_transaction_id]

    entrypoint =
      if key && name do
        [{key, name}]
      else
        []
      end

    tx_id =
      if transaction_id do
        [{"scout_transaction_id", transaction_id}]
      else
        []
      end

    tx_id ++ entrypoint
  end

  defp entrypoint_key_value("Controller", name), do: {"controller_entrypoint", name}
  defp entrypoint_key_value("Job", name), do: {"job_entrypoint", name}
  defp entrypoint_key_value(_type, name), do: {"custom_entrypoint", name}

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
    # Determine the entrypoint layer: prefer Controller/Job from root_layer,
    # then search the layers stack (outermost = last element), then fall back
    # to root_layer or the outermost active layer.
    entrypoint_layer =
      cond do
        root_layer != nil and root_layer.type in ["Controller", "Job"] ->
          root_layer

        # Search layers stack for a Controller/Job (last = outermost)
        (found = Enum.find(Enum.reverse(layers), &(&1.type in ["Controller", "Job"]))) != nil ->
          found

        root_layer != nil ->
          root_layer

        layers != [] ->
          List.last(layers)

        true ->
          nil
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

  defp context_to_attribute(%Context{type: :user, key: key, value: _value})
       when key in ["ip", :ip] do
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
