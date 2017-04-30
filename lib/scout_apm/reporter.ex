defmodule ScoutApm.Reporter do
  require Logger

  @success_http_codes 200..299
  @error_http_codes 400..499

  def post(encoded_payload) do
    host = ScoutApm.Config.find(:host)
    name = ScoutApm.Config.find(:name)
    key = ScoutApm.Config.find(:key)

    gzipped_payload = :zlib.gzip(encoded_payload)
    method = :post

    query = URI.encode_query(%{"key" => key, "name" => name})
    url = <<"#{host}/apps/checkin.scout?#{query}">>

    options = []

    header_list = headers()

    Logger.info("Reporting ScoutAPM Payload to #{url}")
    Logger.debug("Payload Size. JSON: #{inspect :erlang.iolist_size(encoded_payload)}, Gzipped: #{inspect :erlang.iolist_size(gzipped_payload)}")
    # Logger.debug("JSON Payload: #{inspect encoded_payload}")
    # Logger.debug("Headers: #{inspect header_list}")

    case :hackney.request(method, url, header_list , gzipped_payload, options) do

      {:ok, status_code, resp_headers, _client_ref} when status_code in @error_http_codes ->
        Logger.info("Reporting ScoutAPM Payload Failed with #{status_code}. Response Headers: #{inspect resp_headers}")

      {:ok, status_code, _resp_headers, _client_ref} when status_code in @success_http_codes ->
        Logger.info("Reporting ScoutAPM Payload Succeeded. Status: #{inspect status_code}")

      {:ok, status_code, _resp_headers, _client_ref} ->
        Logger.info("Reporting ScoutAPM Payload Unexpected Status: #{inspect status_code}")

      {:error, ereason} ->
        Logger.info("Reporting ScoutAPM Payload Failed: Hackney Error: #{inspect ereason}")

      r ->
        Logger.info("Reporting ScoutAPM Payload Failed: Unknown Hackney Error: #{inspect r}")
    end
  end

  def headers do
    [
      {"Agent-Hostname", ScoutApm.Utils.hostname()},
      {"Agent-Version", ScoutApm.Utils.agent_version()},
      {"Content-Type", "application/json"},
      {"Content-Encoding", "gzip"},
    ]
  end

end
