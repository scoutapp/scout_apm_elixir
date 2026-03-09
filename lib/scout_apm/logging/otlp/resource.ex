defmodule ScoutApm.Logging.OTLP.Resource do
  @moduledoc """
  Builds OTLP Resource attributes for log records.

  The Resource represents the entity producing telemetry and includes
  attributes like service name, version, host, and environment.
  """

  @doc """
  Builds the resource attributes map for OTLP export.
  Returns a list of attribute maps in OTLP format.
  """
  @spec build() :: [map()]
  def build do
    attributes = [
      {"service.name", get_service_name()},
      {"service.version", get_service_version()},
      {"telemetry.sdk.name", "scout_apm_elixir"},
      {"telemetry.sdk.version", get_sdk_version()},
      {"telemetry.sdk.language", "elixir"},
      {"host.name", get_hostname()},
      {"deployment.environment", get_environment()}
    ]

    attributes
    |> Enum.filter(fn {_key, value} -> value != nil and value != "" end)
    |> Enum.map(&to_otlp_attribute/1)
  end

  @doc """
  Converts a {key, value} tuple to OTLP attribute format.
  """
  @spec to_otlp_attribute({String.t(), any()}) :: map()
  def to_otlp_attribute({key, value}) when is_binary(value) do
    %{"key" => key, "value" => %{"stringValue" => value}}
  end

  def to_otlp_attribute({key, value}) when is_integer(value) do
    %{"key" => key, "value" => %{"intValue" => to_string(value)}}
  end

  def to_otlp_attribute({key, value}) when is_float(value) do
    %{"key" => key, "value" => %{"doubleValue" => value}}
  end

  def to_otlp_attribute({key, value}) when is_boolean(value) do
    %{"key" => key, "value" => %{"boolValue" => value}}
  end

  def to_otlp_attribute({key, value}) when is_atom(value) do
    %{"key" => key, "value" => %{"stringValue" => Atom.to_string(value)}}
  end

  def to_otlp_attribute({key, value}) do
    %{"key" => key, "value" => %{"stringValue" => inspect(value)}}
  end

  # Private functions

  defp get_service_name do
    ScoutApm.Config.find(:name) || get_app_name()
  end

  defp get_app_name do
    case Application.get_application(__MODULE__) do
      nil -> "unknown"
      app -> Atom.to_string(app)
    end
  end

  defp get_service_version do
    ScoutApm.Config.find(:revision_sha) || get_app_version()
  end

  defp get_app_version do
    case :application.get_key(:scout_apm, :vsn) do
      {:ok, vsn} -> List.to_string(vsn)
      _ -> nil
    end
  end

  defp get_sdk_version do
    case :application.get_key(:scout_apm, :vsn) do
      {:ok, vsn} -> List.to_string(vsn)
      _ -> "unknown"
    end
  end

  defp get_hostname do
    ScoutApm.Cache.hostname() || get_system_hostname()
  end

  defp get_system_hostname do
    case :inet.gethostname() do
      {:ok, hostname} -> List.to_string(hostname)
      _ -> nil
    end
  end

  defp get_environment do
    case ScoutApm.Config.find(:environment) do
      nil ->
        if function_exported?(Mix, :env, 0) do
          Mix.env() |> to_string()
        else
          "production"
        end

      env ->
        to_string(env)
    end
  end
end
