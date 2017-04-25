defmodule ScoutApm.DevTrace.Plug do
  import Plug.Conn
  require Logger

  # This monkey-patches XMLHttpRequest. It could possibly be part of the main scout_instant.js too. This is placed in the HTML HEAD so it loads as soon as possible.
  xml_http_script_path  = Application.app_dir(:scout_apm, "priv/static/devtrace/xml_http_script.html")
  @xml_http_script File.read!(xml_http_script_path)

  def init(default), do: default

  def call(conn, _) do
    if ScoutApm.DevTrace.enabled? do
      before_send_inject_devtrace(conn)
    else
      conn
    end
  end

  # Phoenix.LiveReloader is used as a base for much of the injection logic.
  defp before_send_inject_devtrace(conn) do
    register_before_send conn, fn conn ->
      resp_body = to_string(conn.resp_body)
      cond do
        async_request?(conn) ->
          add_sync_header(conn)
        inject?(conn, resp_body) ->
          inject_js(conn,resp_body)
        true ->
          conn
      end
    end
  end

  defp add_sync_header(conn) do
    conn
    |> put_resp_header("X-scoutapminstant", payload())
  end

  defp inject_js(conn,resp_body) do
    # HTML HEAD
    [page | rest] = String.split(resp_body, "</head>")
    body = page <> head_tags() <> Enum.join(["</head>" | rest], "")
    # HTML BODY
    [page | rest] = String.split(body, "</body>")
    body = page <> body_tags() <> Enum.join(["</body>" | rest], "")

    put_in conn.resp_body, body
  end

  defp apm_host do
    ScoutApm.Config.find(:host)
  end

  defp cachebust_time do
    :os.system_time(:seconds)
  end

  defp head_tags do
    """
    <link href='#{apm_host()}/instant/scout_instant.css?cachebust=#{cachebust_time()}' media='all' rel='stylesheet' />
    #{@xml_http_script}
    """
  end

  defp body_tags do
    """
    <script src="#{apm_host()}/instant/scout_instant.js?cachebust=#{cachebust_time()}"></script>
    <script>var scoutInstantPageTrace=#{payload()};window.scoutInstant=window.scoutInstant('#{apm_host()}', scoutInstantPageTrace)</script>
    """
  end

  defp payload do
    ScoutApm.DevTrace.Store.payload() |> ScoutApm.DevTrace.Store.encode()
  end

  defp async_request?(conn) do
    ajax_request?(conn) || json_response?(conn)
  end

  defp ajax_request?(conn) do
    conn
    |> get_req_header("x-requested-with")
    |> xml_http?
  end

  defp json_response?(conn) do
    conn
    |> get_resp_header("content-type")
    |> json_content_type?
  end

  # Direct from Phoenix.LiveReloader.inject?/2
  defp inject?(conn, resp_body) do
    conn
    |> get_resp_header("content-type")
    |> html_content_type?
    |> Kernel.&&(String.contains?(resp_body, "<body"))
  end

  # Direct from Phoenix.LiveReloader.inject?/2
  defp html_content_type?([]), do: false
  defp html_content_type?([type | _]), do: String.starts_with?(type, "text/html")

  defp json_content_type?([]), do: false
  defp json_content_type?([type | _]), do: String.starts_with?(type, "application/json")

  defp xml_http?([]), do: false
  defp xml_http?([type | _]), do: String.starts_with?(type, "XMLHttpRequest")
end
