defmodule ScoutApm.Error.ErrorService do
  @moduledoc """
  Background GenServer that batches and sends errors to Scout APM's error endpoint.

  Implements a queue with batching (default 5 errors per batch) and a maximum
  queue size (default 500) to prevent memory issues.
  """

  use GenServer

  alias ScoutApm.Error.ErrorData

  @default_batch_size 5
  @default_max_queue_size 500
  @default_flush_interval_ms 1_000
  @errors_endpoint "/apps/error.scout"

  defstruct [
    :queue,
    :queue_size,
    :timer_ref
  ]

  @type t :: %__MODULE__{
          queue: :queue.queue(ErrorData.t()),
          queue_size: non_neg_integer(),
          timer_ref: reference() | nil
        }

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Sends an error to the service for batched delivery.
  Non-blocking - returns immediately.
  """
  @spec send(ErrorData.t()) :: :ok
  def send(%ErrorData{} = error) do
    GenServer.cast(__MODULE__, {:send, error})
  end

  @doc """
  Waits for the queue to drain. Used in tests and shutdown.
  """
  @spec drain(timeout :: non_neg_integer()) :: :ok | :timeout
  def drain(timeout \\ 5_000) do
    GenServer.call(__MODULE__, :drain, timeout)
  catch
    :exit, _ -> :timeout
  end

  @doc """
  Forces an immediate flush of queued errors. Used in tests.
  """
  @spec flush() :: :ok
  def flush do
    GenServer.call(__MODULE__, :flush)
  end

  # Server Callbacks

  @impl GenServer
  def init(_opts) do
    state = %__MODULE__{
      queue: :queue.new(),
      queue_size: 0,
      timer_ref: nil
    }

    {:ok, schedule_flush(state)}
  end

  @impl GenServer
  def handle_cast({:send, %ErrorData{} = error}, state) do
    max_size = get_max_queue_size()

    if state.queue_size >= max_size do
      ScoutApm.Logger.log(:debug, "Error queue full (#{max_size}), dropping error")
      {:noreply, state}
    else
      new_queue = :queue.in(error, state.queue)
      new_state = %{state | queue: new_queue, queue_size: state.queue_size + 1}

      # If we've hit batch size, flush immediately
      if new_state.queue_size >= get_batch_size() do
        {:noreply, do_flush(new_state)}
      else
        {:noreply, new_state}
      end
    end
  end

  @impl GenServer
  def handle_call(:drain, _from, state) do
    new_state = drain_all(state)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:flush, _from, state) do
    new_state = do_flush(state)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_info(:flush, state) do
    new_state =
      state
      |> do_flush()
      |> schedule_flush()

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl GenServer
  def terminate(_reason, state) do
    drain_all(state)
    :ok
  end

  # Private Functions

  defp schedule_flush(state) do
    if state.timer_ref, do: Process.cancel_timer(state.timer_ref)

    timer_ref = Process.send_after(self(), :flush, get_flush_interval())
    %{state | timer_ref: timer_ref}
  end

  defp do_flush(%{queue_size: 0} = state), do: state

  defp do_flush(state) do
    batch_size = get_batch_size()

    {errors, remaining_queue, remaining_size} =
      dequeue_batch(state.queue, state.queue_size, batch_size)

    if length(errors) > 0 do
      Task.start(fn -> send_errors(errors) end)
    end

    %{state | queue: remaining_queue, queue_size: remaining_size}
  end

  defp drain_all(%{queue_size: 0} = state), do: state

  defp drain_all(state) do
    {errors, remaining_queue, remaining_size} =
      dequeue_batch(state.queue, state.queue_size, state.queue_size)

    if length(errors) > 0 do
      # Send synchronously during drain
      send_errors(errors)
    end

    %{state | queue: remaining_queue, queue_size: remaining_size}
  end

  defp dequeue_batch(queue, queue_size, batch_size) do
    count = min(batch_size, queue_size)

    {errors, new_queue} =
      Enum.reduce(1..max(count, 1), {[], queue}, fn
        _, {acc, q} when length(acc) >= count ->
          {acc, q}

        _, {acc, q} ->
          case :queue.out(q) do
            {{:value, error}, new_q} -> {[error | acc], new_q}
            {:empty, q} -> {acc, q}
          end
      end)

    {Enum.reverse(errors), new_queue, queue_size - length(errors)}
  end

  defp send_errors([]), do: :ok

  defp send_errors(errors) do
    payload = build_payload(errors)

    case Jason.encode(payload) do
      {:ok, json} ->
        compressed = :zlib.gzip(json)
        do_http_send(compressed, length(errors))

      {:error, reason} ->
        ScoutApm.Logger.log(:debug, "Failed to encode error payload: #{inspect(reason)}")
    end
  end

  defp build_payload(errors) do
    %{
      "notifier" => "scout_apm_elixir",
      "environment" => get_environment(),
      "root" => ScoutApm.Config.find(:application_root) || File.cwd!(),
      "problems" => Enum.map(errors, &ErrorData.to_map/1)
    }
  end

  defp get_environment do
    case ScoutApm.Config.find(:environment) do
      nil ->
        if function_exported?(Mix, :env, 0) do
          Mix.env() |> to_string()
        else
          "production"
        end

      env ->
        to_string(env)
    end
  end

  defp do_http_send(body, error_count) do
    url = build_url()
    headers = build_headers(error_count)

    case :hackney.request(:post, url, headers, body, [:with_body]) do
      {:ok, status, _headers, _body} when status < 400 ->
        ScoutApm.Logger.log(:debug, "Successfully sent #{error_count} errors to Scout APM")
        :ok

      {:ok, status, _headers, response_body} ->
        ScoutApm.Logger.log(
          :debug,
          "Error sending to Scout APM errors endpoint. Status: #{status}, Body: #{inspect(response_body)}"
        )

        {:error, {:http_error, status}}

      {:error, reason} ->
        ScoutApm.Logger.log(:debug, "Error sending to Scout APM: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp build_url do
    host = ScoutApm.Config.find(:errors_host) || "https://errors.scoutapm.com"
    key = ScoutApm.Config.find(:key) || ""
    name = ScoutApm.Config.find(:name) || ""

    query = URI.encode_query(%{"key" => key, "name" => name})
    "#{host}#{@errors_endpoint}?#{query}"
  end

  defp build_headers(error_count) do
    [
      {"Agent-Hostname", ScoutApm.Cache.hostname() || ""},
      {"Content-Encoding", "gzip"},
      {"Content-Type", "application/json"},
      {"X-Error-Count", to_string(error_count)}
    ]
  end

  defp get_batch_size, do: ScoutApm.Config.find(:errors_batch_size) || @default_batch_size

  defp get_max_queue_size,
    do: ScoutApm.Config.find(:errors_max_queue_size) || @default_max_queue_size

  defp get_flush_interval,
    do: ScoutApm.Config.find(:errors_flush_interval_ms) || @default_flush_interval_ms
end
