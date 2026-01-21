defmodule ScoutApm.Logging.ContextExtractor do
  @moduledoc """
  Extracts Scout APM context from the current process for log enrichment.

  Reads from Process.get(:scout_apm_request) to extract:
  - scout.request_id - TrackedRequest.id
  - scout.transaction_name - e.g., "Controller/UserController#show"
  - scout.layer_type - Current layer type
  - scout.layer_name - Current layer name
  - scout.tag.{key} - Custom tags from ScoutApm.Context
  - scout.user.{key} - User context
  - service.name - From config
  """

  alias ScoutApm.TrackedRequest
  alias ScoutApm.Internal.Context

  @doc """
  Extracts Scout APM context from the current process.
  Returns a keyword list of context attributes suitable for log enrichment.
  """
  @spec extract() :: keyword()
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
  @spec extract_from_tracked_request(TrackedRequest.t()) :: keyword()
  def extract_from_tracked_request(%TrackedRequest{} = tr) do
    base = base_context()

    request_context = [
      {"scout.request_id", tr.id},
      {"scout.transaction_name", get_transaction_name(tr)},
      {"scout.has_error", tr.error == true}
    ]

    layer_context = extract_layer_context(tr)
    custom_context = extract_custom_context(tr.contexts)

    (base ++ request_context ++ layer_context ++ custom_context)
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

  defp get_transaction_name(%TrackedRequest{root_layer: nil}), do: nil

  defp get_transaction_name(%TrackedRequest{root_layer: layer}) do
    case {layer.type, layer.name} do
      {type, name} when is_binary(type) and is_binary(name) ->
        "#{type}/#{name}"

      {type, nil} when is_binary(type) ->
        type

      _ ->
        nil
    end
  end

  defp extract_layer_context(%TrackedRequest{layers: layers}) when is_list(layers) do
    case layers do
      [current | _] ->
        [
          {"scout.layer_type", current.type},
          {"scout.layer_name", current.name}
        ]

      [] ->
        []
    end
  end

  defp extract_layer_context(_), do: []

  defp extract_custom_context(nil), do: []
  defp extract_custom_context([]), do: []

  defp extract_custom_context(contexts) when is_list(contexts) do
    contexts
    |> Enum.map(&context_to_attribute/1)
    |> Enum.filter(fn {_k, v} -> v != nil end)
  end

  defp context_to_attribute(%Context{type: :extra, key: key, value: value}) do
    {"scout.tag.#{key}", safe_value(value)}
  end

  defp context_to_attribute(%Context{type: :user, key: key, value: value}) do
    {"scout.user.#{key}", safe_value(value)}
  end

  defp context_to_attribute(_), do: {nil, nil}

  defp safe_value(value) when is_binary(value), do: value
  defp safe_value(value) when is_number(value), do: value
  defp safe_value(value) when is_boolean(value), do: value
  defp safe_value(value) when is_atom(value), do: Atom.to_string(value)
  defp safe_value(value), do: inspect(value, limit: 100)
end
