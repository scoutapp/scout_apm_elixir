defmodule ScoutApm.Payload do
  import Logger, only: [info: 1]

  defstruct metadata: %{},
            metrics: %{},
            slow_transactions: %{},
            jobs: %{},
            slow_jobs: %{},
            histograms: %{}

  def new do
    %ScoutApm.Payload{
      metadata: ScoutApm.Payload.Metadata.new(),
      metrics: metrics()
    }
  end

  def metrics do
    [
      %{
        key: %{
          bucket: "Controller",
          name: "Fixed",
          desc: nil,
          extra: nil,
          scope: "",
          scope_hash: %{}
        },
        call_count: 1,
        min_call_time: 1,
        max_call_time: 1,
        total_call_time: 1,
        total_exclusive_time: 1,
        sum_of_squares: 1,
        queue: 0,
        latency: 0,
      }
    ]
  end

  def post(payload) do
    key = ""
    method = :post
    url = <<"http://localhost:3000/apps/checkin.scout?key=#{key}&name=TestElixir">>
    payload = Poison.encode!(payload)
    options = []

    :hackney.start()
    case :hackney.request(method, url, headers(), payload, options) do
      {:ok, status_code, _resp_headers, _client_ref}  -> Logger.info("Ok, status: #{status_code}")
      {:error, ereason} -> Logger.info("Something else: #{ereason}")
    end
  end

  def headers do
    [
      {"Agent-Hostname", "hostname"},
      {"Content-Type", "application/json"},
      {"Agent-Version", "0.0.1"}
    ]
  end

  ## Just a handy thing to not lose
  def application_details do
    Application.spec(:my_app, :vsn)
  end
end

