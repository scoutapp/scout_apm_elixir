defmodule ScoutApm.Payload.AppServerLoad do
  def new() do
    %{
      server_time:        NaiveDateTime.utc_now() |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_iso8601(),
      libraries:          libraries(),
      # framework:          ScoutApm::Environment.instance.framework_integration.human_name,
      # framework_version:  ScoutApm::Environment.instance.framework_integration.version,
      # environment:        ScoutApm::Environment.instance.framework_integration.env,
      # hostname:           ScoutApm::Environment.instance.hostname,
      # application_name:   ScoutApm::Environment.instance.application_name,
      # paas:               ScoutApm::Environment.instance.platform_integration.name,
      # git_sha:            ScoutApm::Environment.instance.git_revision.sha
    }
  end

  defp libraries do
    Enum.map(
      Application.loaded_applications(),
      fn {name, _desc, version} -> [name, to_string version] end)
  end
end
