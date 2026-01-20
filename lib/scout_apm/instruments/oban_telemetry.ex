if Code.ensure_loaded?(Telemetry) || Code.ensure_loaded?(:telemetry) do
  defmodule ScoutApm.Instruments.ObanTelemetry do
    @moduledoc """
    Telemetry handler for Oban job instrumentation.

    Attaches to Oban telemetry events to track background jobs:
    - Job executions appear as "Job" type background transactions
    - Job names are derived from the worker module

    ## Usage

    In your application's `start/2` function:

        def start(_type, _args) do
          ScoutApm.Instruments.ObanTelemetry.attach()
          # ... rest of supervision tree
        end

    This will automatically instrument all Oban job executions in your application.

    ## Transaction Naming

    Jobs are named based on the worker module. For example:
    - `MyApp.Workers.SendEmail` becomes `Job/SendEmail`
    - `MyApp.EmailWorker` becomes `Job/EmailWorker`
    """

    alias ScoutApm.TrackedRequest
    alias ScoutApm.Internal.Layer

    require Logger

    @events [
      [:oban, :job, :start],
      [:oban, :job, :stop],
      [:oban, :job, :exception]
    ]

    @doc """
    Attaches telemetry handlers for Oban job events.

    Call this once during application startup.
    """
    def attach do
      :telemetry.attach_many(
        "scout-apm-oban-telemetry",
        @events,
        &__MODULE__.handle_event/4,
        nil
      )
    end

    @doc """
    Detaches the telemetry handlers. Useful for testing.
    """
    def detach do
      :telemetry.detach("scout-apm-oban-telemetry")
    end

    # Job start - begins a new background transaction
    def handle_event(
          [:oban, :job, :start],
          _measurements,
          %{job: job} = _metadata,
          _config
        ) do
      name = job_name(job)

      # "Job" is the internal layer type for background transactions
      TrackedRequest.start_layer("Job", name)
    end

    # Job stop - completes the transaction
    def handle_event(
          [:oban, :job, :stop],
          _measurements,
          %{job: job, state: state} = _metadata,
          _config
        ) do
      name = job_name(job)

      # Mark as error if job failed, was cancelled, or discarded
      if state in [:failure, :cancelled, :discard] do
        TrackedRequest.mark_error()
      end

      TrackedRequest.stop_layer(fn layer ->
        layer
        |> Layer.update_name(name)
        |> Layer.update_desc("Queue: #{job.queue}, State: #{state}")
      end)
    end

    # Job exception - marks error and completes
    def handle_event(
          [:oban, :job, :exception],
          _measurements,
          %{job: job, kind: kind, reason: reason, stacktrace: stacktrace} = _metadata,
          _config
        ) do
      name = job_name(job)

      TrackedRequest.mark_error()

      # Capture full error details
      ScoutApm.Error.capture_from_telemetry(kind, reason, stacktrace,
        custom_controller: name,
        custom_params: %{queue: job.queue, worker: job.worker}
      )

      TrackedRequest.stop_layer(fn layer ->
        layer
        |> Layer.update_name(name)
        |> Layer.update_desc("#{kind}: #{format_reason(reason)}")
      end)
    end

    # Catch-all for unhandled events
    def handle_event(_event, _measurements, _metadata, _config), do: :ok

    # Format job name from Oban.Job struct
    defp job_name(%{worker: worker}) when is_binary(worker) do
      short_name =
        worker
        |> String.split(".")
        |> List.last()

      "Job/#{short_name}"
    end

    defp job_name(%{worker: worker}) when is_atom(worker) do
      short_name =
        worker
        |> Module.split()
        |> List.last()

      "Job/#{short_name}"
    end

    defp job_name(_job), do: "Job/Unknown"

    defp format_reason(reason) when is_exception(reason) do
      Exception.message(reason)
    end

    defp format_reason(reason) do
      inspect(reason, limit: 100)
    end
  end
end
