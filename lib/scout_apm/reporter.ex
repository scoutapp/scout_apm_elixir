defmodule ScoutApm.Reporter do
  import Logger

  def post(encoded_payload) do
    Logger.info("Encoded payload: #{encoded_payload}")
    key = Application.fetch_env!(:scout_apm, :key)
    method = :post
    url = <<"http://localhost:3000/apps/checkin.scout?key=#{key}&name=TestElixir">>
    options = []

    :hackney.start()
    case :hackney.request(method, url, headers(), encoded_payload, options) do
      {:ok, status_code, _resp_headers, _client_ref} ->
        Logger.info("Ok, status: #{status_code}")
      {:error, ereason} ->
        Logger.info("Failed to Report: #{ereason}")
    end
  end

  def headers do
    [
      {"Agent-Hostname", hostname()},
      {"Content-Type", "application/json"},
      {"Agent-Version", ScoutApm.Utils.agent_version()},
    ]
  end

  def hostname do
    {:ok, name} = :inet.gethostname()
    name
  end
end
