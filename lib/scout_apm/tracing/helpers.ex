defmodule ScoutApm.Tracing.Helpers do
  @moduledoc """
  Functions to time the execution of code.
  """
  require Logger

  @doc """
  Instruments the given `function`, labeling it with `type` and `name` within Scout.

  Within a trace in the Scout UI, the `function` will appear as `type/name` ie "Images/format_avatar".

  __IMPORTANT__: We limit the arity of `type` to 10 per-reporting period. These are displayed in
  charts throughput the UI. These should not be generated dynamically and are designed to be higher-level
  categories (ie Postgres, Redis, HTTP, etc).

  ## Example Usage

      defmodule PhoenixApp.PageController do
        use PhoenixApp.Web, :controller
        import ScoutApm.Tracing.Helpers

        def index(conn, _params) do
          instrument("Timer", "sleep", fn ->
            :timer.sleep(3000)
          end)
          render conn, "index.html", layout: {PhoenixApp.LayoutView, "index.html"}
        end
  """
  def instrument(type, name, function) do
    ScoutApm.TrackedRequest.start_layer(type,name)
    result = function.()
    ScoutApm.TrackedRequest.stop_layer
    result
  end
end
