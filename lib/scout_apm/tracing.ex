defmodule ScoutApm.Tracing do
  @moduledoc """
  Ths module contains functions to create transactions and time the execution of code. It's used to add
  instrumentation to an Elixir app.

  Scout's instrumentation is divided into 2 areas:

  1. __Transactions__: these wrap around a flow of work, like a web request or a GenServer call. The UI groups data under
  transactions. Use `@transaction` module attributes and the `transaction/4` macro.
  2. __Timing__: these measure individual pieces of work, like an HTTP request to an outside service or an Ecto query. Use
  `@timing` module attributes and the `timing/4` macro.

  ## Recording transactions

  There are 2 ways to define transactions:

  1. `@transaction` module attributes
  2. Wrapping blocks of code with the `transaction/4` macro.

  ### Transaction types

  A transaction may be one of two types:

  1. __web__: a transaction that impacts the main app experience, like a Phoenix controller action.
  2. __background__: a transaction that isn't in the main app flow, like a GenServer call or Exq background job.

  If you are instrumenting a stand-alone Elixir app, treat all transactions as `web`. Data from these transactions
  appear in the App overview charts.

  ### Module Attribute Example

  The `@transaction` module attribute works well for treating GenServer calls as distinct transactions. An example instrumenting a Phoenix channel:

      defmodule CampWaitlist.Web.HtmlChannel do
        use Phoenix.Channel
        use ScoutApm.Tracing

        # Will appear under "Web" in the UI, named "CampWaitlist.Web.HtmlChannel.join".
        @transaction(type: "web")
        def join("topic:html", _message, socket) do
          {:ok, socket}
        end

  We treat this as a `web` transaction as it impacts the user experience.

  An example treating a GenServer function as a background job:

      defmodule CampWaitlist.AvailChecker do
        use GenServer
        use ScoutApm.Tracing

        # Will appear under "Background Jobs" in the UI, named "CampWaitlist.AvailChecker.handle_call".
        @transaction(type: "background")
        def handle_call({:check, campground}, _from, state) do
          # Do work...
        end

        # Will appear under "Background Jobs" in the UI, named "AvailChecker.status".
        @transaction(type: "background", name: "AvailChecker.status")
        def handle_call({:status, campground}, _from, state) do
          # Do work...
        end

  ## Timing Code

  There are 2 ways to time the execution of code:

  1. `@timing` module attributes
  2. Wrapping blocks of code with the `timing/4` macro.

  ### Module Attribute Example

      defmodule Searcher do
        use ScoutApm.Tracing

        # Time associated with this function will appear under "Hound" in timeseries charts.
        # The function will appear as `Hound/open_search` in transaction traces.
        @timing(category: "Hound")
        def open_search(url) do
          navigate_to(url)
        end

        # Time associated with this function will appear under "Hound" in timeseries charts.
        # The function will appear as `Hound/search` in transaction traces.
        @timing(category: "Hound", name: "search")
        def open_search(url) do
          navigate_to(url)
        end

  ### Category limitations

  We limit the arity of `category`. These are displayed in charts
  throughput the UI. These should not be generated dynamically and should be limited
  to higher-level categories (ie Postgres, Redis, HTTP, etc).

  ## use vs. import

  To utilize the module attributes (`@transaction` and `@timing`), inject this module via the `use` macro:

      defmodule YourModule
        use ScoutApm.Tracing

  You can then call `transaction/4` and `timing/4` via the following qualified module name, ie:

      ScoutApm.Tracing.timing("HTTP", "GitHub", do: ...)

  To drop the full domain name, you'll need to use the `import` macro. The following is valid:

      defmodule YourModule
        use ScoutApm.Tracing
        import ScoutApm.Tracing

  """

  alias ScoutApm.Internal.Layer
  alias ScoutApm.Internal.Duration
  alias ScoutApm.TrackedRequest

  defmacro __using__(_) do
    quote do
      # This handles module attributes that add instrumentation.
      # See `ScoutApm.Tracing.Annotations`.
      Module.register_attribute(__MODULE__, :scout_transactions, accumulate: true)
      Module.register_attribute(__MODULE__, :scout_timings, accumulate: true)
      Module.register_attribute(__MODULE__, :scout_instrumented, accumulate: false, persist: true)

      @on_definition {ScoutApm.Tracing.Annotations, :on_definition}
      @before_compile {ScoutApm.Tracing.Annotations, :before_compile}
    end
  end

  @doc false
  # Deprecated!
  @spec instrument(String.t, String.t, any, function) :: any
  def instrument(type, name, opts \\ [], function) when is_function(function) do
    ScoutApm.Logger.log(:warn, "#{__MODULE__}.instrument/4 is deprecated, use #{__MODULE__}.timing/4 instead")
    TrackedRequest.start_layer(type, name, opts)
    result = function.()
    TrackedRequest.stop_layer()
    result
  end

  @doc """
  Creates a transaction of `type` (either `web` or `background`) with the given `name` that should be displayed
  in the UI for the provided code `block`.

  ## Example Usage

      import ScoutApm.Tracking

      def do_async_work do
        Task.start(fn ->
          transaction(:background, "do_work") do
            # Do work...
          end
        end)
      end
  """
  defmacro transaction(type, name, opts \\ [], do: block) do
    quote do
      TrackedRequest.start_layer(unquote(internal_layer_type(type)), unquote(name), unquote(opts))
      try do
        (fn -> unquote(block) end).()
      rescue
        e in RuntimeError ->
          # TODO - Add real error tracking
          raise e
      after # ensure we record the transaction if it throws an error
        TrackedRequest.stop_layer()
      end
    end
  end

  defmacro deftransaction(head, body) do
    function_head = Macro.to_string(head)
    quote do
      module = __ENV__.module
               |> Atom.to_string()
               |> String.trim_leading("Elixir.")
      Module.put_attribute(__ENV__.module, :name, "#{module}.#{unquote(function_head)}")

      def unquote(head) do
        transaction(:background, @name, []) do
          unquote(body[:do])
        end
      end

      Module.delete_attribute(__ENV__.module, :name)
    end
  end

  @doc """
  Times the execution of the given `block` of code, labeling it with `category` and `name` within Scout.

  Within a trace in the Scout UI, the `block` will appear as `category/name` ie `Images/format_avatar` in traces and
  will be displayed in timeseries charts under the associated `category`.

  ## Example Usage

      defmodule PhoenixApp.PageController do
        use PhoenixApp.Web, :controller
        import ScoutApm.Tracing

        def index(conn, _params) do
          timing("Timer", "sleep") do
            :timer.sleep(3000)
          end
          render conn, "index.html"
        end
  """
  defmacro timing(category, name, opts \\ [], do: block) do
    quote do
      TrackedRequest.start_layer(unquote(category), unquote(name), unquote(opts))
      try do
        (fn -> unquote(block) end).()
      after # ensure we record the metric if the timed block throws an error
        TrackedRequest.stop_layer()
      end
    end
  end

  # Converts the public-facing type ("web" or "background") to their internal layer representation.
  defp internal_layer_type(type) when is_atom(type) do
    Atom.to_string(type) |> internal_layer_type
  end
  defp internal_layer_type(type) when is_binary(type) do
    downcased = String.downcase(type) # some coercion to handle capitalization
    case downcased do
      "web" ->
        "Controller"
      "background" ->
        "Job"
    end
  end

  @doc """
  Updates the description for the code executing within a call to `timing/4`. The description is displayed
  within a Scout trace in the UI.

  This is useful for logging actual HTTP request URLs, SQL queries, etc.

  ## Example Usage

      timing("HTTP", "httparrot") do
        update_desc("GET: http://httparrot.herokuapp.com/get")
        HTTPoison.get! "http://httparrot.herokuapp.com/get"
      end
  """
  @spec update_desc(String.t) :: any
  def update_desc(desc) do
    TrackedRequest.update_current_layer(fn layer ->
      Layer.update_desc(layer, desc)
    end)
  end

  @doc """
  Adds an timing entry of duration `value` with `units`, labeling it with `category` and `name` within Scout.

  ## Units

  Can be be one of `:microseconds | :milliseconds | :seconds`. These come from `t:ScoutApm.Internal.Duration.unit/0`.

  ## Example Usage

      track("Images", "resize", 200, :milliseconds)
      track("HTTP", "get", 300, :milliseconds, desc: "HTTP GET http://api.github.com/")

  ## Opts

  A `desc` may be provided to add a detailed background of the event. These are viewable when accessing a trace in the UI.

  ## The duration must have actually occured

    This function expects that the `ScoutApm.Internal.Duration` generated by `value` and `units` actually occurs in
    the transaction. The total time of the transaction IS NOT adjusted.

    This naturally occurs when taking the output of Ecto log entries.
  """
  @spec track(String.t, String.t, number(), Duration.unit, keyword()) :: :ok | :error
  def track(category, name, value, units, opts \\ []) when is_number(value) do
    if value < 0 do
      :error
    else
      duration = Duration.new(value, units)
      TrackedRequest.track_layer(category, name, duration, opts)
      :ok
    end
  end
end
