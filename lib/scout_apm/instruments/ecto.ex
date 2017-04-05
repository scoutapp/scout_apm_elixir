defmodule ScoutApm.Instruments.Ecto do
  alias ScoutApm.Internal.Layer

  defmacro __using__(_args) do
    quote unquote: false do
      contents = quote do
        require Logger

        def aggregate(a,b,c) do
          __trace(fn -> unquote(__MODULE__).aggregate(a,b,c) end)
        end

        def aggregate(a,b,c,d) do
          __trace(fn -> unquote(__MODULE__).aggregate(a,b,c,d) end)
        end

        def all(a) do
          __trace(fn -> unquote(__MODULE__).all(a) end)
        end

        def all(a,b) do
          __trace(fn -> unquote(__MODULE__).all(a,b) end)
        end

        def config() do
          __trace(fn -> unquote(__MODULE__).config() end)
        end

        def delete!(a) do
          __trace(fn -> unquote(__MODULE__).delete!(a) end)
        end

        def delete!(a,b) do
          __trace(fn -> unquote(__MODULE__).delete!(a, b) end)
        end

        def delete(a) do
          __trace(fn -> unquote(__MODULE__).delete(a) end)
        end

        def delete(a,b) do
          __trace(fn -> unquote(__MODULE__).delete(a,b) end)
        end

        def delete_all(a) do
          __trace(fn -> unquote(__MODULE__).delete_all(a) end)
        end

        def delete_all(a,b) do
          __trace(fn -> unquote(__MODULE__).delete_all(a,b) end)
        end

        def get!(a,b) do
          __trace(fn -> unquote(__MODULE__).get!(a,b) end)
        end

        def get!(a,b,c) do
          __trace(fn -> unquote(__MODULE__).get!(a,b,c) end)
        end

        def get(a,b) do
          __trace(fn -> unquote(__MODULE__).get(a,b) end)
        end

        def get(a,b,c) do
          __trace(fn -> unquote(__MODULE__).get(a,b,c) end)
        end

        def get_by!(a,b) do
          __trace(fn -> unquote(__MODULE__).get_by!(a,b) end)
        end

        def get_by!(a,b,c) do
          __trace(fn -> unquote(__MODULE__).get_by!(a,b,c) end)
        end

        def get_by(a,b) do
          __trace(fn -> unquote(__MODULE__).get_by(a,b) end)
        end

        def get_by(a,b,c) do
          __trace(fn -> unquote(__MODULE__).get_by(a,b,c) end)
        end

        def in_transaction?() do
          __trace(fn -> unquote(__MODULE__).in_transaction?() end)
        end

        def insert!(a) do
          __trace(fn -> unquote(__MODULE__).insert!(a) end)
        end

        def insert!(a,b) do
          __trace(fn -> unquote(__MODULE__).insert!(a,b) end)
        end

        def insert(a) do
          __trace(fn -> unquote(__MODULE__).insert(a) end)
        end

        def insert(a,b) do
          __trace(fn -> unquote(__MODULE__).insert(a,b) end)
        end

        def insert_all(a,b) do
          __trace(fn -> unquote(__MODULE__).insert_all(a,b) end)
        end

        def insert_all(a,b,c) do
          __trace(fn -> unquote(__MODULE__).insert_all(a,b,c) end)
        end

        def insert_or_update!(a) do
          __trace(fn -> unquote(__MODULE__).insert_or_update!(a) end)
        end

        def insert_or_update!(a,b) do
          __trace(fn -> unquote(__MODULE__).insert_or_update!(a,b) end)
        end

        def insert_or_update(a) do
          __trace(fn -> unquote(__MODULE__).insert_or_update(a) end)
        end

        def insert_or_update(a,b) do
          __trace(fn -> unquote(__MODULE__).insert_or_update(a,b) end)
        end

        def load(a,b) do
          __trace(fn -> unquote(__MODULE__).load(a,b) end)
        end

        def one!(a) do
          __trace(fn -> unquote(__MODULE__).one!(a) end)
        end

        def one!(a,b) do
          __trace(fn -> unquote(__MODULE__).one!(a,b) end)
        end

        def one(a) do
          __trace(fn -> unquote(__MODULE__).one(a) end)
        end

        def one(a,b) do
          __trace(fn -> unquote(__MODULE__).one(a,b) end)
        end

        def preload(a,b) do
          __trace(fn -> unquote(__MODULE__).preload(a,b) end)
        end

        def preload(a,b,c) do
          __trace(fn -> unquote(__MODULE__).preload(a,b,c) end)
        end

        def query!(a) do
          __trace(fn -> unquote(__MODULE__).query!(a) end)
        end

        def query!(a,b) do
          __trace(fn -> unquote(__MODULE__).query!(a,b) end)
        end

        def query!(a,b,c) do
          __trace(fn -> unquote(__MODULE__).query!(a,b,c) end)
        end

        def query(a) do
          __trace(fn -> unquote(__MODULE__).query(a) end)
        end

        def query(a,b) do
          __trace(fn -> unquote(__MODULE__).query(a,b) end)
        end

        def query(a,b,c) do
          __trace(fn -> unquote(__MODULE__).query(a,b,c) end)
        end

        def rollback(a) do
          __trace(fn -> unquote(__MODULE__).rollback(a) end)
        end

        def stop(a) do
          __trace(fn -> unquote(__MODULE__).stop(a) end)
        end

        def stop(a,b) do
          __trace(fn -> unquote(__MODULE__).stop(a,b) end)
        end

        def stream(a) do
          __trace(fn -> unquote(__MODULE__).stream(a) end)
        end

        def stream(a,b) do
          __trace(fn -> unquote(__MODULE__).stream(a,b) end)
        end

        def transaction(a) do
          __trace(fn -> unquote(__MODULE__).transaction(a) end)
        end

        def transaction(a,b) do
          __trace(fn -> unquote(__MODULE__).transaction(a,b) end)
        end

        def update!(a) do
          __trace(fn -> unquote(__MODULE__).update!(a) end)
        end

        def update!(a,b) do
          __trace(fn -> unquote(__MODULE__).update!(a,b) end)
        end

        def update(a) do
          __trace(fn -> unquote(__MODULE__).update(a) end)
        end

        def update(a,b) do
          __trace(fn -> unquote(__MODULE__).update(a,b) end)
        end

        def update_all(a,b) do
          __trace(fn -> unquote(__MODULE__).update_all(a,b) end)
        end

        def update_all(a,b,c) do
          __trace(fn -> unquote(__MODULE__).update_all(a,b,c) end)
        end

        defp __trace(f) do
          ScoutApm.TrackedRequest.start_layer("Ecto", nil)
          ecto_result = f.()
          log_entry = Process.get(:ecto_log_entry)
          ScoutApm.TrackedRequest.stop_layer(
            ScoutApm.Instruments.Ecto.name_query(log_entry),
            fn layer -> ScoutApm.Instruments.Ecto.annotate_layer_callback(layer, log_entry) end)
          ecto_result
        end
      end

      scout_repo_module =
        __MODULE__
        |> Atom.to_string
        |> (Kernel.<> ".ScoutApm")
        |> String.to_atom

      Module.create(scout_repo_module, contents, __ENV__)
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

  def annotate_layer_callback(layer, ecto_log) do
    backtrace = Process.info(self(), :current_stacktrace)

    layer
    |> Layer.update_desc(ecto_log.query)
    |> Layer.update_backtrace(backtrace)
  end
end

