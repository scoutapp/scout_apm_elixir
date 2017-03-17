defmodule ScoutApm.Instruments.EctoLogger do
  require Logger


  # [info] Entry: 
  # %Ecto.LogEntry{
    # ansi_color: nil,
    # connection_pid: nil,
    # decode_time: 16000,
    # params: [],
    # query: "SELECT u0.\"id\", u0.\"name\", u0.\"age\" FROM \"users\" AS u0",
    # query_time: 1192999,
    # queue_time: 36000,
    # result: {:ok,
    #    %Postgrex.Result{
    #      columns: ["id", "name", "age"], 
    #      command: :select,
    #      connection_id: 70629,
    #      num_rows: 1, 
    #      rows: [[%TestappPhoenix.User{__meta__: #Ecto.Schema.Metadata<:loaded, "users">, age: 32, id: 1, name: "chris"}]]}
   #      },
    # source: "users"}
  def log(entry) do
    # Logger.info("Entry: #{inspect entry}")
    # Logger.info("Query: #{entry.query}")
    # Logger.info("Query Time: #{entry.query_time}")
    # Logger.info("Queue Time: #{entry.queue_time}")
    # Logger.info("Num Rows: #{num_rows(entry)}")

    ScoutApm.TrackedRequest.store_layer("Ecto", name_query(entry), query_time(entry))

    Process.put(:ecto_log_entry, entry)

    entry
  end

  def log(entry, level) do
    Logger.info("Level: #{level}")
    log(entry)
  end

  defp query_time(entry) do
    raw_time = entry.query_time
    System.convert_time_unit(raw_time, :native, :microsecond) / 1_000_000
  end

  defp name_query(entry) do
    command = case entry.result do
      {:ok, result} -> result.command
      _ -> "Unknown"
    end

    table = entry.source

    "#{command}##{table}"
  end

  defp num_rows(entry) do
    case entry.result do
      {:ok, result} -> result.num_rows
      _ -> 0
    end
  end
end
