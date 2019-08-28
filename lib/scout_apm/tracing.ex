defmodule ScoutApm.Tracing do
  @moduledoc """
  Ths module contains functions to create transactions and time the execution of code. It's used to add
  instrumentation to an Elixir app.

  Scout's instrumentation is divided into 2 areas:

  1. __Transactions__: these wrap around a flow of work, like a web request or a GenServer call. The UI groups data under
  transactions.
  2. __Timing__: these measure individual pieces of work, like an HTTP request to an outside service or an Ecto query.

  ### Transaction types

  A transaction may be one of two types:

  1. __web__: a transaction that impacts the main app experience, like a Phoenix controller action.
  2. __background__: a transaction that isn't in the main app flow, like a GenServer call or Exq background job.

  If you are instrumenting a stand-alone Elixir app, treat all transactions as `web`. Data from these transactions
  appear in the App overview charts.

  ### deftransaction Macro Example

  Replace your function `def` with `deftransaction` to instrument it.
  You can override the name and type by setting the `@transaction_opts` attribute right before the function.

      defmodule CampWaitlist.Web.HtmlChannel do
        use Phoenix.Channel
        import ScoutApm.Tracing

        # Will appear under "Web" in the UI, named "CampWaitlist.Web.HtmlChannel.join".
        @transaction_opts [type: "web"]
        deftransaction join("topic:html", _message, socket) do
          {:ok, socket}
        end

  ## Timing Code

  ### deftiming Macro Example

      defmodule Searcher do
        import ScoutApm.Tracing

        # Time associated with this function will appear under "Hound" in timeseries charts.
        # The function will appear as `Hound/open_search` in transaction traces.
        @timing_opts [category: "Hound"]
        deftiming open_search(url) do
          navigate_to(url)
        end

        # Time associated with this function will appear under "Hound" in timeseries charts.
        # The function will appear as `Hound/search` in transaction traces.
        @timing_opts [name: "search", category: "Hound"]
        deftiming open_search(url) do
          navigate_to(url)
        end

  ### Category limitations

  We limit the arity of `category`. These are displayed in charts
  throughput the UI. These should not be generated dynamically and should be limited
  to higher-level categories (ie Postgres, Redis, HTTP, etc).

  ## use vs. import

  To utilize the `deftransaction` and `deftiming` macros, import this module:

      defmodule YourModule
        import ScoutApm.Tracing

  To utilize the module attributes (`@transaction` and `@timing`), inject this module via the `use` macro:

      defmodule YourModule
        use ScoutApm.Tracing

  You can then call `transaction/4` and `timing/4` via the following qualified module name, ie:

      ScoutApm.Tracing.timing("HTTP", "GitHub", do: ...)

  To drop the full module name, you'll need to use the `import` macro. The following is valid:

      defmodule YourModule
        use ScoutApm.Tracing
        import ScoutApm.Tracing


  If you are importing across multiple libraries, it is possible to run into naming collisions.  Elixir
  has documentation around those issues [here](https://elixir-lang.org/getting-started/alias-require-and-import.html).
  """

  alias ScoutApm.Internal.Layer
  alias ScoutApm.Internal.Duration
  alias ScoutApm.TrackedRequest

  @doc false
  defmacro transaction(type, name, opts \\ [], do: block) do
    quote do
      TrackedRequest.start_layer(
        ScoutApm.Tracing.internal_layer_type(unquote(type)),
        unquote(name),
        unquote(opts)
      )

      # ensure we record the transaction if it throws an error
      try do
        (fn -> unquote(block) end).()
      rescue
        e in RuntimeError ->
          # TODO - Add real error tracking
          raise e
      after
        TrackedRequest.stop_layer()
      end
    end
  end

  @doc """
  Creates a transaction defaulting to type `background` with the default name being the fully qualified module, function and arity.

  You can override the name and type by setting the `@transaction_opts` attribute right before the function.

  ## Example Usage

      import ScoutApm.Tracking

      # @transaction_opts [type: "web", name: "name_override"]
      deftransaction do_async_work() do
        # Do work...
      end
  """
  defmacro deftransaction(head, body) do
    function_head = Macro.to_string(head)

    quote do
      options = Module.delete_attribute(__MODULE__, :transaction_opts) || []

      module =
        __MODULE__
        |> Atom.to_string()
        |> String.trim_leading("Elixir.")

      name = Keyword.get(options, :name, "#{module}.#{unquote(function_head)}")
      type = Keyword.get(options, :type, "background")
      Module.put_attribute(__MODULE__, :scout_name, name)
      Module.put_attribute(__MODULE__, :scout_type, type)

      def unquote(head) do
        transaction(@scout_type, @scout_name) do
          unquote(body[:do])
        end
      end

      Module.delete_attribute(__MODULE__, :scout_name)
      Module.delete_attribute(__MODULE__, :scout_type)
    end
  end

  @doc false
  defmacro timing(category, name, opts \\ [], do: block) do
    quote do
      TrackedRequest.start_layer(unquote(category), unquote(name), unquote(opts))
      # ensure we record the metric if the timed block throws an error
      try do
        (fn -> unquote(block) end).()
      after
        TrackedRequest.stop_layer()
      end
    end
  end

  @doc """
  Times the execution of the given function, labeling it with a `category` and `name` within Scout. The default category is "Custom", and the default name is the fully qualified module, function and arity.

  You can override the category and name by setting the `@timing_opts` attribute right before the function.

  Within a trace in the Scout UI, the block will appear as `category/name` ie `Images/format_avatar` in traces and
  will be displayed in timeseries charts under the associated `category`.

  ## Example Usage

      defmodule PhoenixApp.PageController do
        use PhoenixApp.Web, :controller
        import ScoutApm.Tracing

        # @timing_opts [category: "Images", name: "format_images"]
        deftiming format_avatars(params) do
          # Formatting avatars
        end

        def index(conn, params) do
          format_avatars(params)
          render conn, "index.html"
        end
  """
  defmacro deftiming(head, body) do
    function_head = Macro.to_string(head)

    quote do
      options = Module.delete_attribute(__MODULE__, :timing_opts) || []

      module =
        __MODULE__
        |> Atom.to_string()
        |> String.trim_leading("Elixir.")

      name = Keyword.get(options, :name, "#{module}.#{unquote(function_head)}")
      category = Keyword.get(options, :category, "Custom")
      Module.put_attribute(__MODULE__, :scout_name, name)
      Module.put_attribute(__MODULE__, :scout_category, category)

      def unquote(head) do
        timing(@scout_category, @scout_name) do
          unquote(body[:do])
        end
      end

      Module.delete_attribute(__MODULE__, :scout_name)
      Module.delete_attribute(__MODULE__, :scout_type)
    end
  end

  # Converts the public-facing type ("web" or "background") to their internal layer representation.
  def internal_layer_type(type) when is_atom(type) do
    Atom.to_string(type) |> internal_layer_type
  end

  def internal_layer_type(type) when is_binary(type) do
    # some coercion to handle capitalization
    downcased = String.downcase(type)

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
  @spec update_desc(String.t()) :: any
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
  @spec track(String.t(), String.t(), number(), Duration.unit(), keyword()) :: :ok | :error
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
