defmodule ScoutApm.Logging.OTLP.Exporter do
  @moduledoc """
  HTTP transport for sending logs to an OTLP collector.

  Sends log records via HTTP POST to the /v1/logs endpoint.
  Supports gzip compression for payloads over 1KB.
  """

  alias ScoutApm.Logging.OTLP.Encoder
  alias ScoutApm.Logging.LogRecord

  @logs_endpoint "/v1/logs"
  @compression_threshold 1024

  @doc """
  Exports a batch of log records to the configured OTLP endpoint.
  Returns :ok on success or {:error, reason} on failure.
  """
  @spec export([LogRecord.t()]) :: :ok | {:error, term()}
  def export([]), do: :ok

  def export(log_records) when is_list(log_records) do
    payload = Encoder.encode(log_records)

    case Jason.encode(payload) do
      {:ok, json} ->
        {body, content_encoding} = maybe_compress(json)
        do_http_send(body, content_encoding, length(log_records))

      {:error, reason} ->
        ScoutApm.Logger.log(:debug, "Failed to encode log payload: #{inspect(reason)}")
        {:error, {:encode_error, reason}}
    end
  end

  # Private functions

  defp maybe_compress(json) when byte_size(json) > @compression_threshold do
    {:zlib.gzip(json), "gzip"}
  end

  defp maybe_compress(json) do
    {json, nil}
  end

  defp do_http_send(body, content_encoding, log_count) do
    url = build_url()
    headers = build_headers(content_encoding)

    case :hackney.request(:post, url, headers, body, [:with_body]) do
      {:ok, status, _headers, _body} when status < 300 ->
        ScoutApm.Logger.log(:debug, "Successfully sent #{log_count} logs to OTLP collector")
        :ok

      {:ok, status, _headers, response_body} ->
        ScoutApm.Logger.log(
          :debug,
          "Error sending logs to OTLP collector. Status: #{status}, Body: #{inspect(response_body)}"
        )

        {:error, {:http_error, status}}

      {:error, reason} ->
        ScoutApm.Logger.log(:debug, "Error sending logs to OTLP collector: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp build_url do
    endpoint = get_endpoint()

    # Ensure endpoint doesn't have trailing slash
    endpoint = String.trim_trailing(endpoint, "/")
    "#{endpoint}#{@logs_endpoint}"
  end

  defp get_endpoint do
    ScoutApm.Config.find(:logs_endpoint) || "https://otlp.scoutotel.com:4318"
  end

  defp build_headers(content_encoding) do
    base_headers = [
      {"Content-Type", "application/json"},
      {"x-scout-key", get_ingest_key()},
      {"User-Agent", "scout_apm_elixir/#{get_version()}"}
    ]

    if content_encoding do
      [{"Content-Encoding", content_encoding} | base_headers]
    else
      base_headers
    end
  end

  defp get_ingest_key do
    ScoutApm.Config.find(:logs_ingest_key) || ScoutApm.Config.find(:key) || ""
  end

  defp get_version do
    case :application.get_key(:scout_apm, :vsn) do
      {:ok, vsn} -> List.to_string(vsn)
      _ -> "unknown"
    end
  end
end
