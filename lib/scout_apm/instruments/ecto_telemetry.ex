if Code.ensure_loaded?(Telemetry) || Code.ensure_loaded?(:telemetry) do
  defmodule ScoutApm.Instruments.EctoTelemetry do
    @doc """
    Attaches an event handler for Ecto queries.

    Takes a fully namespaced Ecto.Repo module as the only argument. Example:

        ScoutApm.Instruments.EctoTelemetry.attach(MyApp.Repo)
    """
    def attach(repo_module) do
      query_event =
        repo_module
        |> Module.split()
        |> Enum.map(&(&1 |> Macro.underscore() |> String.to_atom()))
        |> Kernel.++([:query])

      :telemetry.attach(
        "ScoutApm Ecto Instrument Hook for " <> Macro.underscore(repo_module),
        query_event,
        &ScoutApm.Instruments.EctoTelemetry.handle_event/4,
        nil
      )
    end

    def handle_event(query_event, _value, metadata, _config) when is_list(query_event) do
      if :query == List.last(query_event) do
        ScoutApm.Instruments.EctoLogger.record(metadata)
      end
    end
  end
end
