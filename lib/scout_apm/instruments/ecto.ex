defmodule ScoutApm.Instruments.Ecto do

  defmacro __using__(_args) do
    # IO.puts (inspect __CALLER__.module)
    # IO.puts (inspect Module.definitions_in(__CALLER__.module))

    # IO.puts (inspect __ENV__.module)
    # IO.puts (inspect Module.definitions_in(__ENV__.module))

    quote unquote: false do
      contents = quote do
        # IO.puts (inspect Module.definitions_in unquote(__MODULE__))

        require Logger

        def all(query) do
          Logger.info("Tracking Ecto Request")
          ScoutApm.TrackedRequest.start_layer("Ecto", nil)
          result = unquote(__MODULE__).all(query)
          log_entry = Process.get(:ecto_log_entry)
          ScoutApm.TrackedRequest.stop_layer(
            ScoutApm.Instruments.Ecto.name_query(log_entry))
        end
      end

      Module.create(ScoutApm.Repo, contents, __ENV__)
    end
  end

  def query_time(entry) do
    raw_time = entry.query_time
    System.convert_time_unit(raw_time, :native, :microsecond) / 1_000_000
  end

  def name_query(entry) do
    command = case entry.result do
      {:ok, result} -> result.command
      _ -> "Unknown"
    end

    table = entry.source

    "#{command}##{table}"
  end

  def num_rows(entry) do
    case entry.result do
      {:ok, result} -> result.num_rows
      _ -> 0
    end
  end
end

