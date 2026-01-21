defmodule ScoutApm.Logging.LogService do
  @moduledoc """
  Background GenServer that batches and sends log records to an OTLP collector.

  Implements a queue with batching and a maximum queue size to prevent memory issues.
  Follows the same pattern as ScoutApm.Error.ErrorService.
  """

  use GenServer

  alias ScoutApm.Logging.LogRecord
  alias ScoutApm.Logging.OTLP.Exporter

  @default_batch_size 100
  @default_max_queue_size 5000
  @default_flush_interval_ms 5_000

  defstruct [
    :queue,
    :queue_size,
    :timer_ref
  ]

  @type t :: %__MODULE__{
          queue: :queue.queue(LogRecord.t()),
          queue_size: non_neg_integer(),
          timer_ref: reference() | nil
        }

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Sends a log record to the service for batched delivery.
  Non-blocking - returns immediately.
  """
  @spec send(LogRecord.t()) :: :ok
  def send(%LogRecord{} = record) do
    if enabled?() do
      GenServer.cast(__MODULE__, {:send, record})
    else
      :ok
    end
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
  Forces an immediate flush of queued logs. Used in tests.
  """
  @spec flush() :: :ok
  def flush do
    GenServer.call(__MODULE__, :flush)
  end

  @doc """
  Returns the current queue size.
  """
  @spec queue_size() :: non_neg_integer()
  def queue_size do
    GenServer.call(__MODULE__, :queue_size)
  catch
    :exit, _ -> 0
  end

  @doc """
  Checks if logging is enabled.
  """
  @spec enabled?() :: boolean()
  def enabled? do
    ScoutApm.Config.find(:logs_enabled) == true
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
  def handle_cast({:send, %LogRecord{} = record}, state) do
    max_size = get_max_queue_size()

    if state.queue_size >= max_size do
      ScoutApm.Logger.log(:debug, "Log queue full (#{max_size}), dropping log record")
      {:noreply, state}
    else
      new_queue = :queue.in(record, state.queue)
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
  def handle_call(:queue_size, _from, state) do
    {:reply, state.queue_size, state}
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

    {records, remaining_queue, remaining_size} =
      dequeue_batch(state.queue, state.queue_size, batch_size)

    if length(records) > 0 do
      Task.start(fn -> Exporter.export(records) end)
    end

    %{state | queue: remaining_queue, queue_size: remaining_size}
  end

  defp drain_all(%{queue_size: 0} = state), do: state

  defp drain_all(state) do
    {records, remaining_queue, remaining_size} =
      dequeue_batch(state.queue, state.queue_size, state.queue_size)

    if length(records) > 0 do
      # Send synchronously during drain
      Exporter.export(records)
    end

    %{state | queue: remaining_queue, queue_size: remaining_size}
  end

  defp dequeue_batch(queue, queue_size, batch_size) do
    count = min(batch_size, queue_size)

    {records, new_queue} =
      Enum.reduce(1..max(count, 1), {[], queue}, fn
        _, {acc, q} when length(acc) >= count ->
          {acc, q}

        _, {acc, q} ->
          case :queue.out(q) do
            {{:value, record}, new_q} -> {[record | acc], new_q}
            {:empty, q} -> {acc, q}
          end
      end)

    {Enum.reverse(records), new_queue, queue_size - length(records)}
  end

  defp get_batch_size, do: ScoutApm.Config.find(:logs_batch_size) || @default_batch_size

  defp get_max_queue_size,
    do: ScoutApm.Config.find(:logs_max_queue_size) || @default_max_queue_size

  defp get_flush_interval,
    do: ScoutApm.Config.find(:logs_flush_interval_ms) || @default_flush_interval_ms
end
