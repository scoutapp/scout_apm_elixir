defmodule ScoutApm.DevTrace.Plug do
  import Plug.Conn
  require Logger

  def init(default), do: default

  def call(conn, _) do
    # TODO - add a config setting to only run if devtrace: true ... or possibly default to true in development.
    before_send_inject_devtrace(conn)
  end

  # Phoenix.LiveReloader is used as a base for much of the injection logic.
  defp before_send_inject_devtrace(conn) do
    register_before_send conn, fn conn ->
      resp_body = to_string(conn.resp_body)
      if inject?(conn, resp_body) do
        # HTML HEAD
        [page | rest] = String.split(resp_body, "</head>")
        body = page <> head_tags() <> Enum.join(["</head>" | rest], "")
        # HTML BODY
        [page | rest] = String.split(body, "</body>")
        body = page <> body_tags() <> Enum.join(["</body>" | rest], "")

        put_in conn.resp_body, body
      else
        conn
      end
    end
  end

  defp apm_host do
    ScoutApm.Config.find(:host)
  end

  defp cachebust_time do
    :os.system_time(:seconds)
  end

  defp head_tags do
    """
    <link href='#{apm_host}/instant/scout_instant.css?cachebust=#{cachebust_time}' media='all' rel='stylesheet' />
    """
  end

  defp body_tags do
    """
    <script src="#{apm_host}/instant/scout_instant.js?cachebust=#{cachebust_time}"></script>
    <script>var scoutInstantPageTrace=#{payload};window.scoutInstant=window.scoutInstant('#{apm_host}', scoutInstantPageTrace)</script>
    """
  end

  defp payload do
    # How to access the current transaction trace? How to format in JSON?
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
end
