defmodule ScoutApm.Instruments.EctoLogger do
  # value = %{
  # decode_time: 5386000,
  # query_time: 9435000,
  # queue_time: 4549000,
  # total_time: 19370000
  # }
  # metadata = %{
  # params: [1],
  # query: "SELECT p0.\"id\", p0.\"body\", p0.\"title\", p0.\"inserted_at\", p0.\"updated_at\" FROM \"posts\" AS p0 WHERE (p0.\"id\" = $1)",
  # repo: MyApp.Repo,
  # result: :ok,
  # source: "posts",
  # type: :ecto_sql_query
  # }

  def log(entry) do
    case query_time_log_entry(entry) do
      {:ok, duration} ->
        {command, num_rows} = extract_result_info(entry)

        ScoutApm.TrackedRequest.track_layer(
          "Ecto",
          query_name_log_entry(entry),
          duration,
          desc: Map.get(entry, :query),
          db_command: command,
          db_rows: num_rows
        )

      {:error, _} ->
        nil
    end

    entry
  end

  def record(value, metadata) do
    case query_time(value, metadata) do
      {:ok, duration} ->
        {command, num_rows} = extract_result_info(metadata)

        ScoutApm.TrackedRequest.track_layer(
          "Ecto",
          query_name(value, metadata),
          duration,
          desc: Map.get(metadata, :query),
          db_command: command,
          db_rows: num_rows
        )

      {:error, _} ->
        nil
    end
  end

  def query_name(_value, metadata) do
    case Map.get(metadata, :source) do
      nil -> "SQL"
      table_name -> "SQL##{table_name}"
    end
  end

  def query_name_log_entry(entry) do
    with {:ok, {:ok, result}} <- Map.fetch(entry, :result),
         command <- Map.get(result, :command, "SQL"),
         table <- Map.get(entry, :source) do
      command =
        List.wrap(command)
        |> Enum.map(&to_string(&1))
        |> Enum.join(",")

      if table do
        "#{command}##{table}"
      else
        "#{command}"
      end
    else
      _ ->
        "SQL"
    end
  end

  def query_time(%{query_time: query_time}, _telemetry_metadata) when is_integer(query_time) do
    microtime = System.convert_time_unit(query_time, :native, :microsecond)
    {:ok, ScoutApm.Internal.Duration.new(microtime, :microseconds)}
  end

  def query_time(_telemetry_value, %{query_time: query_time}) when is_integer(query_time) do
    microtime = System.convert_time_unit(query_time, :native, :microsecond)
    {:ok, ScoutApm.Internal.Duration.new(microtime, :microseconds)}
  end

  def query_time(_telemetry_value, _telemetry_metadata) do
    {:error, :non_integer_query_time}
  end

  def query_time_log_entry(%{query_time: query_time}) when is_integer(query_time) do
    microtime = System.convert_time_unit(query_time, :native, :microsecond)
    {:ok, ScoutApm.Internal.Duration.new(microtime, :microseconds)}
  end

  def query_time_log_entry(_entry) do
    {:error, :non_integer_query_time}
  end

  @doc false
  def extract_result_info(%{result: {:ok, result}}) do
    command = Map.get(result, :command)
    num_rows = Map.get(result, :num_rows)
    {normalize_command(command), num_rows}
  end

  def extract_result_info(_), do: {nil, nil}

  defp normalize_command(:select), do: "Select"
  defp normalize_command(:insert), do: "Insert"
  defp normalize_command(:update), do: "Update"
  defp normalize_command(:delete), do: "Delete"

  defp normalize_command(cmd) when is_atom(cmd) and not is_nil(cmd),
    do: cmd |> to_string() |> String.capitalize()

  defp normalize_command(_), do: nil
end
