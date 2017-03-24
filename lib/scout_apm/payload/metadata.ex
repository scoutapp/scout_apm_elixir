defmodule ScoutApm.Payload.Metadata do
  defstruct [
    :app_root,
    :unique_id,
    :agent_version,
    :agent_time,
    :agent_pid,
    :platform
  ]

  def new do
    %__MODULE__{
      app_root: System.cwd(),
      unique_id: ScoutApm.Utils.random_string(20),
      agent_version: ScoutApm.Utils.agent_version(),
      agent_time: DateTime.utc_now() |> DateTime.to_iso8601(),
      agent_pid: System.get_pid(),
      platform: "elixir",
    }
  end

end
