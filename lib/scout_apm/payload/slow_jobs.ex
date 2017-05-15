defmodule ScoutApm.Payload.SlowJobs do

  alias ScoutApm.Internal.Duration

  def new(job_traces) do
    Enum.map(job_traces, &make_slow_job_payload/1)
  end

  def make_slow_job_payload(job_trace) do
    %{
      queue: job_trace.queue_name,
      name: job_trace.job_name,
      time: job_trace.time,

      total_time: Duration.as(job_trace.total_time, :seconds),
      exclusive_time: Duration.as(job_trace.exclusive_time, :seconds),

      hostname: job_trace.hostname,
      metrics: ScoutApm.Payload.NewMetrics.new(job_trace.metrics),
      context: ScoutApm.Payload.Context.new(job_trace.contexts),

      score: job_trace.score,

      # Unimplemented parts of this payload. Kept here to remind us of
      # the symmetry w/ the ruby agent
      #
      # allocation_metrics: MetricsToJsonSerializer.new(job.allocation_metrics).as_json, # New style of metrics
      # truncated_metrics: job.truncated_metrics,
      # git_sha: job.git_sha,
      # allocations: job.allocations,
      # mem_delta: job.mem_delta,
      # seconds_since_startup: job.seconds_since_startup,
    }
  end
end
