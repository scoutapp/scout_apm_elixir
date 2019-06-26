defmodule ScoutApm.Payload.AppServerLoad do
  @moduledoc """
  A separate payload from the rest, this is data sent up at application
  boot time. This allows the UI to know immeidately when a new application
  starts up, and helps us debug interactions with various 3rd party libraries
  """

  @doc """
  Create a new Map containing the payload.
  """
  def new() do
    %{
      server_time:
        NaiveDateTime.utc_now() |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_iso8601(),
      libraries: libraries(),
      application_name: ScoutApm.Config.find(:name),
      hostname: ScoutApm.Cache.hostname(),
      git_sha: ScoutApm.Cache.git_sha()
      # framework:          ScoutApm::Environment.instance.framework_integration.human_name,
      # framework_version:  ScoutApm::Environment.instance.framework_integration.version,
      # environment:        ScoutApm::Environment.instance.framework_integration.env,
      # paas:               ScoutApm::Environment.instance.platform_integration.name,
    }
  end

  defp libraries do
    Enum.map(
      Application.loaded_applications(),
      fn {name, _desc, version} -> [to_string(name), to_string(version)] end
    )
  end
end
