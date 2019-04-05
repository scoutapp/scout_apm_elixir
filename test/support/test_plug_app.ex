defmodule ScoutApm.TestPlugApp do
  use Plug.Router

  plug(:match)
  plug(:add_private_phoenix_controller)
  plug(ScoutApm.Plugs.ControllerTimer)
  plug(:dispatch)

  get "/" do
    conn = fetch_query_params(conn)

    if Map.get(conn.query_params, "ignore") == "true" do
      ScoutApm.TrackedRequest.ignore()
    end

    put_private(conn, :phoenix_action, :index)
    |> send_resp(200, "")
  end

  get "/500" do
    put_private(conn, :phoenix_action, :"500")
    |> send_resp(500, "")
  end

  get "/x-forwarded-for" do
    put_req_header(conn, "x-forwarded-for", "1.2.3.4")
    |> put_private(:phoenix_action, :"x-forwarded-for")
    |> send_resp(200, "")
  end

  def add_private_phoenix_controller(conn, _opts) do
    put_private(conn, :phoenix_controller, Elixir.MyTestApp.PageController)
  end
end
