defmodule ScoutApm.Plugs.ControllerTimer do
  alias ScoutApm.Internal.Layer
  alias ScoutApm.{Context, TrackedRequest, Config}
  @queue_headers ~w(x-queue-start x-request-start)

  def init(default), do: default

  def call(conn, _default) do
    if !ignore_uri?(conn.request_path) do
      queue_time = get_queue_time_diff_nanoseconds(conn)
      TrackedRequest.start_layer("Controller", action_name(conn))

      if queue_time do
        Context.add("scout.queue_time_ns", "#{queue_time}")
      end

      conn
      |> Plug.Conn.register_before_send(&before_send/1)
    else
      TrackedRequest.ignore()

      conn
    end
  end

  def before_send(conn) do
    full_name = action_name(conn)
    uri = "#{conn.request_path}"

    add_ip_context(conn)
    maybe_mark_error(conn)

    TrackedRequest.stop_layer(fn layer ->
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
    TrackedRequest.mark_error()
    conn
  end

  def maybe_mark_error(conn), do: conn

  @doc """
  Takes a connection, extracts the phoenix controller & action, then manipulates
  & cleans it up.

  Returns a string like "PageController#index"
  """
  @spec action_name(Plug.Conn.t()) :: String.t()
  def action_name(conn) do
    action_name = conn.private[:phoenix_action]

    conn.private[:phoenix_controller]
    |> Module.split()
    # Remove app module name (if configured)
    |> Enum.drop(num_parts_to_drop())
    |> Enum.join(".")
    # Append action
    |> String.replace_suffix("", "##{action_name}")
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

    Context.add_user(:ip, remote_ip)
  end

  defp get_queue_time_diff_nanoseconds(conn) do
    unix_now =
      DateTime.utc_now()
      |> DateTime.to_unix(:millisecond)

    queue_start_ms =
      Enum.find_value(@queue_headers, fn header ->
        case Plug.Conn.get_req_header(conn, header) do
          [timestamp] when is_binary(timestamp) ->
            timestamp

          [] ->
            nil
        end
      end)

    with true <- is_binary(queue_start_ms),
         {queue_start_ms_unix, ""} <- parse_request_start_time(queue_start_ms) do
      (unix_now - queue_start_ms_unix)
      |> abs()
      |> System.convert_time_unit(:millisecond, :nanosecond)
    else
      _ -> nil
    end
  end

  defp parse_request_start_time("t=" <> queue_start_ms) do
    Integer.parse(queue_start_ms)
  end

  defp parse_request_start_time(queue_start_ms) do
    Integer.parse(queue_start_ms)
  end

  defp num_parts_to_drop do
    if Config.find(:trim_app_module_name), do: 1, else: 0
  end
end
