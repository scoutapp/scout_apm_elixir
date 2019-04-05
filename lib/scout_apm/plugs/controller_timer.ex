defmodule ScoutApm.Plugs.ControllerTimer do
  alias ScoutApm.Internal.Layer

  def init(default), do: default

  def call(conn, _default) do
    if !ignore_uri?(conn.request_path) do
      ScoutApm.TrackedRequest.start_layer("Controller", action_name(conn))

      conn
      |> Plug.Conn.register_before_send(&before_send/1)
    else
      ScoutApm.TrackedRequest.ignore()

      conn
    end
  end

  def before_send(conn) do
    full_name = action_name(conn)
    uri = "#{conn.request_path}"

    add_ip_context(conn)
    maybe_mark_error(conn)

    ScoutApm.TrackedRequest.stop_layer(fn layer ->
      layer
      |> Layer.update_name(full_name)
      |> Layer.update_uri(uri)
    end)

    conn
  end

  @spec ignore_uri?(String.t()) :: boolean()
  def ignore_uri?(uri) do
    ScoutApm.Config.find(:ignore)
    |> Enum.any?(fn prefix ->
      String.starts_with?(uri, prefix)
    end)
  end

  def maybe_mark_error(conn = %{status: 500}) do
    ScoutApm.TrackedRequest.mark_error()
    conn
  end

  def maybe_mark_error(conn), do: conn

  # Takes a connection, extracts the phoenix controller & action, then manipulates & cleans it up.
  # Returns a string like "PageController#index"
  def action_name(conn) do
    controller_name = conn.private[:phoenix_controller]
    action_name = conn.private[:phoenix_action]

    # a string like "Elixir.TestappPhoenix.PageController#index"
    "#{controller_name}##{action_name}"
    # Split into a list
    |> String.split(".")
    # drop "Elixir.TestappPhoenix", leaving just ["PageController#index"]
    |> Enum.drop(2)
    # Probably just "joining" a 1 elem array, but recombine this way anyway in case of periods
    |> Enum.join(".")
  end

  defp add_ip_context(conn) do
    remote_ip =
      case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
        [forwarded_ip | _] ->
          forwarded_ip

        _ ->
          conn.remote_ip
          |> Tuple.to_list()
          |> Enum.join(".")
      end

    ScoutApm.Context.add_user(:ip, remote_ip)
  end
end
