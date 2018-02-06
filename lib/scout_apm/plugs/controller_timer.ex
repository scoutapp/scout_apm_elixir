defmodule ScoutApm.Plugs.ControllerTimer do
  alias ScoutApm.Internal.Layer

  def init(default), do: default

  def call(conn, _default) do
    if !ignore_uri?(conn.request_path) do
      ScoutApm.TrackedRequest.start_layer("Controller", action_name(conn))

      conn
      |> Plug.Conn.register_before_send(&before_send/1)
    else
      conn
    end
  end

  def before_send(conn) do
    full_name = action_name(conn)
    uri = "#{conn.request_path}"

    add_ip_context(conn)

    ScoutApm.TrackedRequest.stop_layer(
      fn layer ->
        layer
        |> Layer.update_name(full_name)
        |> Layer.update_uri(uri)
      end
    )

    conn
  end

  @spec ignore_uri?(String.t()) :: boolean()
  def ignore_uri?(uri) do
    ScoutApm.Config.find(:ignore)
    |> Enum.any?(fn(prefix) ->
      String.starts_with?(uri, prefix)
    end)
  end

  # Takes a connection, extracts the phoenix controller & action, then manipulates & cleans it up.
  # Returns a string like "PageController#index"
  defp action_name(conn) do
    controller_name = conn.private[:phoenix_controller]
    action_name = conn.private[:phoenix_action]

    "#{controller_name}##{action_name}" # a string like "Elixir.TestappPhoenix.PageController#index"
      |>  String.split(".") # Split into a list
      |>  Enum.drop(2) # drop "Elixir.TestappPhoenix", leaving just ["PageController#index"]
      |>  Enum.join(".") # Probably just "joining" a 1 elem array, but recombine this way anyway in case of periods
  end

  defp add_ip_context(conn) do
    try do
      remote_ips = Plug.Conn.get_req_header(conn, "x-forwarded-for")
      forwarded_ip = List.first(remote_ips)

      remote_ip =
        if forwarded_ip do
          forwarded_ip
        else
          conn.remote_ip
          |> Tuple.to_list
          |> Enum.join(".")
        end

      ScoutApm.Context.add_user(:ip, remote_ip)
    rescue
      err ->
        ScoutApm.Logger.log(:debug, "Failed adding IP context: #{inspect err}")
    end
  end
end
