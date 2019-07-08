defprotocol ScoutApm.Command do
  def message(data)
end

defmodule ScoutApm.Command.Register do
  defstruct [:app, :key]
  alias __MODULE__

  defimpl ScoutApm.Command, for: __MODULE__ do
    def message(%Register{app: app, key: key}) do
      %{
        Register: %{
          app: app,
          key: key,
          language: "elixir",
          api_version: "1.0"
        }
      }
    end
  end
end

defmodule ScoutApm.Command.StartSpan do
  @enforce_keys [:timestamp]
  defstruct [:timestamp, :request_id, :span_id, :parent, :operation]
  alias __MODULE__

  defimpl ScoutApm.Command, for: __MODULE__ do
    def message(%StartSpan{} = span) do
      %{
        StartSpan: %{
          timestamp: "#{NaiveDateTime.to_iso8601(span.timestamp)}Z",
          request_id: span.request_id,
          span_id: span.span_id,
          parent_id: span.parent,
          operation: span.operation
        }
      }
    end
  end
end

defmodule ScoutApm.Command.StopSpan do
  @enforce_keys [:timestamp]
  defstruct [:timestamp, :request_id, :span_id]
  alias __MODULE__

  defimpl ScoutApm.Command, for: __MODULE__ do
    def message(%StopSpan{} = span) do
      %{
        StopSpan: %{
          timestamp: "#{NaiveDateTime.to_iso8601(span.timestamp)}Z",
          request_id: span.request_id,
          span_id: span.span_id
        }
      }
    end
  end
end

defmodule ScoutApm.Command.StartRequest do
  @enforce_keys [:timestamp]
  defstruct [:timestamp, :request_id]
  alias __MODULE__

  defimpl ScoutApm.Command, for: __MODULE__ do
    def message(%StartRequest{} = request) do
      %{
        StartRequest: %{
          timestamp: "#{NaiveDateTime.to_iso8601(request.timestamp)}Z",
          request_id: request.request_id
        }
      }
    end
  end
end

defmodule ScoutApm.Command.FinishRequest do
  @enforce_keys [:timestamp]
  defstruct [:timestamp, :request_id]
  alias __MODULE__

  defimpl ScoutApm.Command, for: __MODULE__ do
    def message(%FinishRequest{} = request) do
      %{
        FinishRequest: %{
          timestamp: "#{NaiveDateTime.to_iso8601(request.timestamp)}Z",
          request_id: request.request_id
        }
      }
    end
  end
end

defmodule ScoutApm.Command.TagSpan do
  @enforce_keys [:timestamp]
  defstruct [:timestamp, :request_id, :span_id, :tag, :value]
  alias __MODULE__

  defimpl ScoutApm.Command, for: __MODULE__ do
    def message(%TagSpan{} = span) do
      %{
        TagSpan: %{
          timestamp: "#{NaiveDateTime.to_iso8601(span.timestamp)}Z",
          request_id: span.request_id,
          span_id: span.span_id,
          tag: span.tag,
          value: span.value
        }
      }
    end
  end
end

defmodule ScoutApm.Command.TagRequest do
  @enforce_keys [:timestamp]
  defstruct [:timestamp, :request_id, :tag, :value]
  alias __MODULE__

  defimpl ScoutApm.Command, for: __MODULE__ do
    def message(%TagRequest{} = request) do
      %{
        TagRequest: %{
          timestamp: "#{NaiveDateTime.to_iso8601(request.timestamp)}Z",
          request_id: request.request_id,
          tag: request.tag,
          value: request.value
        }
      }
    end
  end
end

defmodule ScoutApm.Command.ApplicationEvent do
  @enforce_keys [:timestamp]
  defstruct [:timestamp, :event_type, :event_value, :source]
  alias __MODULE__

  def app_metadata do
    %ApplicationEvent{
      timestamp: NaiveDateTime.utc_now(),
      event_type: "scout.metadata",
      event_value: %{
        language: "elixir",
        version: System.version(),
        server_time: "#{NaiveDateTime.to_iso8601(NaiveDateTime.utc_now())}Z",
        framework: "",
        framework_version: "",
        environment: "",
        app_server: "",
        hostname: ScoutApm.Cache.hostname(),
        database_engine: "",
        database_adapter: "",
        application_name: ScoutApm.Config.find(:name),
        libraries: libraries(),
        paas: "",
        application_root: "",
        git_sha: ScoutApm.Cache.git_sha()
      },
      source: inspect(self())
    }
  end

  defp libraries do
    Enum.map(
      Application.loaded_applications(),
      fn {name, _desc, version} -> [to_string(name), to_string(version)] end
    )
  end

  defimpl ScoutApm.Command, for: __MODULE__ do
    def message(%ApplicationEvent{} = event) do
      %{
        ApplicationEvent: %{
          timestamp: "#{NaiveDateTime.to_iso8601(event.timestamp)}Z",
          event_type: event.event_type,
          event_value: event.event_value,
          source: event.source
        }
      }
    end
  end
end

defmodule ScoutApm.Command.CoreAgentVersion do
  defstruct []
  alias __MODULE__

  defimpl ScoutApm.Command, for: __MODULE__ do
    def message(%CoreAgentVersion{} = _version) do
      %{
        CoreAgentVersion: %{}
      }
    end
  end
end

defmodule ScoutApm.Command.Batch do
  @enforce_keys [:commands]
  defstruct [:commands]
  alias __MODULE__
  alias ScoutApm.Command
  alias ScoutApm.Internal.Layer

  def from_tracked_request(request) do
    request_id = ScoutApm.Utils.random_string(12)

    start_request = %Command.StartRequest{
      timestamp: request.root_layer.started_at,
      request_id: request_id
    }

    commands = [start_request]

    tag_requests =
      Enum.map(request.contexts, fn %{key: key, value: value} ->
        %Command.TagRequest{
          timestamp: start_request.timestamp,
          request_id: start_request.request_id,
          tag: key,
          value: value
        }
      end)

    commands = commands ++ tag_requests

    spans = build_layer_spans([request.root_layer], request_id, nil, [])

    spans =
      if request.error == true do
        spans ++
          [
            %Command.TagSpan{
              timestamp: request.root_layer.started_at,
              request_id: request_id,
              tag: "error",
              value: "true"
            }
          ]
      else
        spans
      end

    commands = commands ++ spans

    finish_request = %Command.FinishRequest{
      timestamp: request.root_layer.stopped_at,
      request_id: request_id
    }

    commands = commands ++ [finish_request]

    %Batch{
      commands: commands
    }
  end

  defimpl ScoutApm.Command, for: __MODULE__ do
    def message(%Batch{commands: commands}) do
      %{
        BatchCommand: %{
          commands: Enum.map(commands, &ScoutApm.Command.message(&1))
        }
      }
    end
  end

  defp build_layer_spans(children, request_id, parent_id, spans) do
    Enum.reduce(children, spans, fn child, spans ->
      [start | rest] = layer_to_spans(child, request_id, parent_id)
      build_layer_spans(child.children, request_id, start.span_id, spans ++ [start | rest])
    end)
  end

  defp layer_to_spans(layer, request_id, parent_span_id) do
    span_id = ScoutApm.Utils.random_string(12)

    start_span = %Command.StartSpan{
      timestamp: layer.started_at,
      request_id: request_id,
      span_id: span_id,
      parent: parent_span_id,
      operation: operation(layer)
    }

    stop_timestamp =
      if layer.manual_duration do
        NaiveDateTime.add(layer.started_at, layer.manual_duration.value, :microsecond)
      else
        layer.stopped_at
      end

    stop_span = %Command.StopSpan{
      timestamp: stop_timestamp,
      request_id: request_id,
      span_id: span_id
    }

    tag_spans = tag_spans(layer, request_id, span_id)

    [start_span, stop_span] ++ tag_spans
  end

  defp operation(%Layer{type: "Controller"} = layer), do: "#{layer.type}/#{layer.name}"
  defp operation(%Layer{type: "Job"} = layer), do: "#{layer.type}/#{layer.name}"
  defp operation(%Layer{type: "Ecto"}), do: "SQL/Query"
  defp operation(%Layer{type: "EEx"}), do: "Template/Render"
  defp operation(%Layer{type: "Exs"}), do: "Template/Render"
  defp operation(layer), do: "#{layer.type}/#{layer.name}"

  defp tag_spans(%Layer{type: "Ecto"} = layer, request_id, span_id) do
    [
      %Command.TagSpan{
        timestamp: layer.started_at,
        request_id: request_id,
        span_id: span_id,
        tag: "db.statement",
        value: layer.desc
      }
    ]
  end

  defp tag_spans(%Layer{type: type} = layer, request_id, span_id) when type in ["EEx", "Exs"] do
    [
      %Command.TagSpan{
        timestamp: layer.started_at,
        request_id: request_id,
        span_id: span_id,
        tag: "scout.desc",
        value: layer.name
      }
    ]
  end

  defp tag_spans(_layer, _request_id, _span_id), do: []
end
