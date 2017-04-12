defmodule ScoutApm.Reporter do
  require Logger

  def post(encoded_payload) do
    host = ScoutApm.Config.find(:host)
    name = ScoutApm.Config.find(:name)
    key = ScoutApm.Config.find(:key)

    gzipped_payload = :zlib.gzip(encoded_payload)
    method = :post
    url = <<"#{host}/apps/checkin.scout?key=#{key}&name=#{name}">>
    options = []

    header_list = headers()

    Logger.info("Reporting ScoutAPM Payload to #{url}")

    case :hackney.request(method, url, header_list , gzipped_payload, options) do
      {:ok, status_code, _resp_headers, _client_ref} ->
        Logger.info("Reporting ScoutAPM Payload Succeeded")
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
