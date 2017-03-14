defmodule ScoutApm.Plugs.ControllerTimer do
  require Logger

  def init(default), do: default

  def call(conn, _default) do
    t1 = System.monotonic_time(:microseconds)

    conn
    |> Plug.Conn.register_before_send(fn conn -> before_send(t1, conn) end)
  end

  def before_send(t1, conn) do
    controller_name = conn.private[:phoenix_controller]
    action_name = conn.private[:phoenix_action]
    full_name =
      "#{controller_name}##{action_name}"
      |>  String.split(".")
      |>  Enum.drop(2) # TODO: Revisit - this should drop "Elixir.TestappPhoenix", leaving just ["PageController#index"]
      |>  Enum.join(".")

    t2 = System.monotonic_time(:microseconds)
    tdiff = (t2 - t1) / 1_000_000

    ScoutApm.Worker.register_layer("Controller", full_name, tdiff)

    conn
  end

  def print_payload(payload) do
    Logger.info Poison.encode!(payload)
  end
end
