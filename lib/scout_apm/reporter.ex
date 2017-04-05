defmodule ScoutApm.Reporter do
  require Logger

  def post(encoded_payload) do
    IO.puts encoded_payload
    host = ScoutApm.Config.find(:host)
    name = ScoutApm.Config.find(:name)
    key = ScoutApm.Config.find(:key)
    gzipped_payload = :zlib.gzip(encoded_payload)

    method = :post
    url = <<"#{host}/apps/checkin.scout?key=#{key}&name=#{name}">>
    options = []

    Logger.info("Posting payload to #{url}")

    case :hackney.request(method, url, headers(), gzipped_payload, options) do
      {:ok, status_code, _resp_headers, _client_ref} ->
        Logger.info("Ok, status: #{status_code}")
      {:error, ereason} ->
        Logger.info("Failed to Report: #{ereason}")
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
