defmodule ScoutApm.Reporter do
  require Logger

  def post(encoded_payload) do
    # Logger.info("Post: Start with encoded payload: #{encoded_payload}")

    Logger.info("Post: Starting post")

    host = ScoutApm.Config.find(:host)
    name = ScoutApm.Config.find(:name)
    key = ScoutApm.Config.find(:key)
    Logger.info("Post: Got config values")

    gzipped_payload = :zlib.gzip(encoded_payload)
    Logger.info("Post: Gzipped Payload")

    method = :post
    url = <<"#{host}/apps/checkin.scout?key=#{key}&name=#{name}">>
    options = []

    header_list = headers()
    Logger.info("Post: Headers: #{inspect header_list}")

    Logger.info("Post: Calling Hackney - #{inspect method} to #{url}")
    case :hackney.request(method, url, header_list , gzipped_payload, options) do
      {:ok, status_code, _resp_headers, _client_ref} ->
        Logger.info("Post: Hackney Returned ok: status: #{inspect status_code}")
      {:error, ereason} ->
        Logger.info("Post: Hackney Failed to Report: #{inspect ereason}")
      r ->
        Logger.info("Post: Hackney Unknown hackney response: #{inspect r}")
    end

    Logger.info("Post: Finished posting")
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
