defmodule ScoutApm.ApplicationLoadNotification do
  use GenServer

  @name __MODULE__

  # Milliseconds
  @wait_between_retries 10_000

  def start_link() do
    GenServer.start_link(__MODULE__, :ok, name: @name)
  end

  ################
  #  Public API  #
  ################
  def init(:ok) do
    initial_state = %{}
    run(retries: 3)

    {:ok, initial_state}
  end

  def run(retries: retries) do
    GenServer.cast(@name, {:run, [retries: retries]})
  end

  ###############
  #  Callbacks  #
  ###############

  def handle_cast({:run, [retries: retries]}, state) do
    payload =
      ScoutApm.Payload.AppServerLoad.new()
      |> Poison.encode!()

    # post/1 logs errors and successes, so only log if we stop retrying
    case report(payload) do
      :ok ->
        {:stop, :normal, state}

      :error ->
        if retries < 1 do
          ScoutApm.Logger.log(:info, "Failed to send AppServerLoad, aborting.")
          {:stop, :normal, state}
        else
          :timer.sleep(@wait_between_retries)
          run(retries: retries - 1)
          {:noreply, state}
        end
    end
  end

  # TODO: Refactor posting logic to recombine this w/ Reporter
  @success_http_codes 200..299
  @error_http_codes 400..499

  defp report(encoded_payload) do
    monitor = ScoutApm.Config.find(:monitor)
    key = ScoutApm.Config.find(:key)

    case {monitor, key} do
      {nil, nil} ->
        ScoutApm.Logger.log(
          :debug,
          "Skipping AppServerLoad, both monitor and key settings are missing"
        )

        :ok

      {true, nil} ->
        ScoutApm.Logger.log(:debug, "Skipping AppServerLoad, key is nil")
        :ok

      {true, ""} ->
        ScoutApm.Logger.log(:debug, "Skipping AppServerLoad, key is empty")
        :ok

      {nil, _} ->
        ScoutApm.Logger.log(:debug, "Skipping AppServerLoad, monitor is nil")
        :ok

      {false, _} ->
        ScoutApm.Logger.log(:debug, "Skipping AppServerLoad, monitor is false")
        :ok

      _ ->
        post(encoded_payload)
    end
  end

  defp post(encoded_payload) do
    host = ScoutApm.Config.find(:host)
    name = ScoutApm.Config.find(:name)
    key = ScoutApm.Config.find(:key)

    method = :post
    query = URI.encode_query(%{"key" => key, "name" => name})
    url = <<"#{host}/apps/app_server_load.scout?#{query}">>
    options = []
    header_list = headers()

    case :hackney.request(method, url, header_list, encoded_payload, options) do
      {:ok, status_code, _resp_headers, _client_ref} when status_code in @success_http_codes ->
        ScoutApm.Logger.log(
          :info,
          "AppServerLoad Report Succeeded. Status: #{inspect(status_code)}"
        )

        :ok

      {:ok, status_code, resp_headers, _client_ref} when status_code in @error_http_codes ->
        ScoutApm.Logger.log(
          :info,
          "AppServerLoad Report Failed with #{status_code}. Response Headers: #{
            inspect(resp_headers)
          }"
        )

        :error

      {:ok, status_code, _resp_headers, _client_ref} ->
        ScoutApm.Logger.log(
          :info,
          "AppServerLoad Report Unexpected Status: #{inspect(status_code)}"
        )

        :error

      {:error, ereason} ->
        ScoutApm.Logger.log(
          :info,
          "AppServerLoad Report Failed: Hackney Error: #{inspect(ereason)}"
        )

        :error

      r ->
        ScoutApm.Logger.log(
          :info,
          "AppServerLoad Report Failed: Unknown Hackney Error: #{inspect(r)}"
        )

        :error
    end
  end

  defp headers do
    [
      {"Agent-Hostname", ScoutApm.Cache.hostname()},
      {"Agent-Version", ScoutApm.Utils.agent_version()},

      # This is not technically correct, it should be application/json
      # or a custom content-type, but due to how ingest works, this is the
      # correct thing for now.
      {"Content-Type", "application/octet-stream"}
    ]
  end
end
