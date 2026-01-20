defmodule ScoutApm.Error.ErrorData do
  @moduledoc """
  Internal representation of an error to be sent to Scout APM.
  Matches the Python agent's error data structure for backend compatibility.
  """

  alias ScoutApm.Error.ParameterFilter

  defstruct [
    :exception_class,
    :message,
    :request_id,
    :request_uri,
    :request_params,
    :request_session,
    :environment,
    :trace,
    :request_components,
    :context,
    :host,
    :revision_sha
  ]

  @type t :: %__MODULE__{
          exception_class: String.t(),
          message: String.t(),
          request_id: String.t() | nil,
          request_uri: String.t() | nil,
          request_params: map() | nil,
          request_session: map() | nil,
          environment: map() | nil,
          trace: [String.t()],
          request_components: map() | nil,
          context: map(),
          host: String.t() | nil,
          revision_sha: String.t() | nil
        }

  @doc """
  Creates an ErrorData struct from an Elixir exception.
  """
  @spec from_exception(Exception.t(), keyword()) :: t()
  def from_exception(exception, opts \\ []) do
    stacktrace = Keyword.get(opts, :stacktrace) || get_current_stacktrace()

    %__MODULE__{
      exception_class: exception_class_name(exception),
      message: Exception.message(exception),
      request_id: get_request_id(),
      request_uri: Keyword.get(opts, :request_path),
      request_params: opts |> Keyword.get(:request_params) |> ParameterFilter.filter(),
      request_session: opts |> Keyword.get(:session) |> ParameterFilter.filter(),
      environment: opts |> Keyword.get(:environment) |> ParameterFilter.filter(),
      trace: format_stacktrace(stacktrace),
      request_components: build_request_components(opts),
      context: build_context(opts),
      host: ScoutApm.Cache.hostname(),
      revision_sha: ScoutApm.Cache.git_sha()
    }
  end

  @doc """
  Creates an ErrorData struct from telemetry exception data.
  """
  @spec from_telemetry(:error | :throw | :exit, term(), Exception.stacktrace(), keyword()) ::
          t() | nil
  def from_telemetry(:error, reason, stacktrace, opts) when is_exception(reason) do
    from_exception(reason, Keyword.put(opts, :stacktrace, stacktrace))
  end

  def from_telemetry(:error, reason, stacktrace, opts) do
    %__MODULE__{
      exception_class: "ErlangError",
      message: inspect(reason, limit: 500),
      request_id: get_request_id(),
      request_uri: Keyword.get(opts, :request_path),
      request_params: opts |> Keyword.get(:request_params) |> ParameterFilter.filter(),
      request_session: opts |> Keyword.get(:session) |> ParameterFilter.filter(),
      environment: nil,
      trace: format_stacktrace(stacktrace),
      request_components: build_request_components(opts),
      context: build_context(opts),
      host: ScoutApm.Cache.hostname(),
      revision_sha: ScoutApm.Cache.git_sha()
    }
  end

  def from_telemetry(:throw, reason, stacktrace, opts) do
    %__MODULE__{
      exception_class: "ThrowError",
      message: inspect(reason, limit: 500),
      request_id: get_request_id(),
      request_uri: Keyword.get(opts, :request_path),
      request_params: opts |> Keyword.get(:request_params) |> ParameterFilter.filter(),
      request_session: opts |> Keyword.get(:session) |> ParameterFilter.filter(),
      environment: nil,
      trace: format_stacktrace(stacktrace),
      request_components: build_request_components(opts),
      context: build_context(opts),
      host: ScoutApm.Cache.hostname(),
      revision_sha: ScoutApm.Cache.git_sha()
    }
  end

  def from_telemetry(:exit, reason, stacktrace, opts) do
    %__MODULE__{
      exception_class: "ExitError",
      message: inspect(reason, limit: 500),
      request_id: get_request_id(),
      request_uri: Keyword.get(opts, :request_path),
      request_params: opts |> Keyword.get(:request_params) |> ParameterFilter.filter(),
      request_session: opts |> Keyword.get(:session) |> ParameterFilter.filter(),
      environment: nil,
      trace: format_stacktrace(stacktrace),
      request_components: build_request_components(opts),
      context: build_context(opts),
      host: ScoutApm.Cache.hostname(),
      revision_sha: ScoutApm.Cache.git_sha()
    }
  end

  @doc """
  Converts the ErrorData to a map suitable for JSON encoding.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = error) do
    %{
      "exception_class" => error.exception_class,
      "message" => error.message,
      "request_id" => error.request_id,
      "request_uri" => error.request_uri,
      "request_params" => error.request_params,
      "request_session" => error.request_session,
      "environment" => error.environment,
      "trace" => error.trace,
      "request_components" => error.request_components,
      "context" => error.context,
      "host" => error.host,
      "revision_sha" => error.revision_sha
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  # Private helpers

  defp exception_class_name(exception) do
    exception.__struct__
    |> Module.split()
    |> List.last()
  end

  defp get_request_id do
    case Process.get(:scout_apm_request) do
      %{id: id} -> id
      _ -> ScoutApm.Utils.random_string(12)
    end
  end

  defp get_current_stacktrace do
    {:current_stacktrace, stacktrace} = Process.info(self(), :current_stacktrace)
    # Drop the first few frames that are internal to this module
    Enum.drop(stacktrace, 4)
  end

  defp format_stacktrace(stacktrace) do
    scm_subdirectory = ScoutApm.Config.find(:scm_subdirectory) || ""

    stacktrace
    # Limit to 50 frames like Python
    |> Enum.take(50)
    |> Enum.map(fn
      {mod, fun, arity, location} when is_integer(arity) ->
        file = Keyword.get(location, :file, ~c"nofile") |> to_string()
        line = Keyword.get(location, :line, 0)

        file_path =
          if scm_subdirectory != "", do: Path.join(scm_subdirectory, file), else: file

        "#{file_path}:#{line}:in #{inspect(mod)}.#{fun}/#{arity}"

      {mod, fun, args, location} when is_list(args) ->
        file = Keyword.get(location, :file, ~c"nofile") |> to_string()
        line = Keyword.get(location, :line, 0)
        arity = length(args)

        file_path =
          if scm_subdirectory != "", do: Path.join(scm_subdirectory, file), else: file

        "#{file_path}:#{line}:in #{inspect(mod)}.#{fun}/#{arity}"

      frame ->
        Exception.format_stacktrace_entry(frame)
    end)
  end

  defp build_request_components(opts) do
    custom_controller = Keyword.get(opts, :custom_controller)

    # Try to get from tracked request
    tracked_request = Process.get(:scout_apm_request)

    cond do
      custom_controller ->
        %{"module" => nil, "controller" => custom_controller, "action" => nil}

      tracked_request && tracked_request.root_layer ->
        parse_controller_action(tracked_request.root_layer.name)

      tracked_request && length(tracked_request.layers) > 0 ->
        # Get the bottom-most layer (first in list since it's a stack)
        layer = List.last(tracked_request.layers)
        parse_controller_action(layer.name)

      true ->
        nil
    end
  end

  defp parse_controller_action(nil), do: nil

  defp parse_controller_action(name) do
    case String.split(name, "#", parts: 2) do
      [controller, action] ->
        %{"module" => nil, "controller" => controller, "action" => action}

      [controller] ->
        %{"module" => nil, "controller" => controller, "action" => nil}
    end
  end

  defp build_context(opts) do
    custom_params = Keyword.get(opts, :custom_params, %{})
    user_context = Keyword.get(opts, :context, %{})

    # Get context from tracked request
    tracked_request = Process.get(:scout_apm_request)

    request_context =
      if tracked_request do
        contexts_map =
          tracked_request.contexts
          |> Enum.map(fn %{key: k, value: v} -> {k, v} end)
          |> Map.new()

        Map.put(contexts_map, "transaction_id", tracked_request.id)
      else
        %{}
      end

    base_context =
      request_context
      |> Map.merge(user_context)

    # Only add custom_params if not empty
    if map_size(custom_params) > 0 do
      Map.put(base_context, "custom_params", custom_params)
    else
      base_context
    end
    |> Enum.reject(fn {_k, v} -> v == %{} or is_nil(v) end)
    |> Map.new()
  end
end
