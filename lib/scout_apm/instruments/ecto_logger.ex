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
    Process.put(:ecto_log_entry, entry)
    entry
  end
end
