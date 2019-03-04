if Code.ensure_loaded?(Telemetry) do
  defmodule ScoutApm.Instruments.EctoTelemetry do
    @doc """
    Attaches an event handler for Ecto queries.

    Takes a fully namespaced Ecto.Repo module as the only argument. Example:

        ScoutApm.Instruments.EctoTelemetry.attach(MyApp.Repo)
    """
    def attach(repo_module) do
      query_event =
        repo_module
        |> Macro.underscore()
        |> String.to_atom()

      Telemetry.attach(
        "scout-ecto-query-handler",
        [query_event, :query],
        ScoutApm.Instruments.EctoTelemetry,
        :handle_event,
        nil
      )
    end

    def handle_event([_query_event, :query], _value, metadata, _config) do
      ScoutApm.Instruments.EctoLogger.record(metadata)
    end
  end
end
