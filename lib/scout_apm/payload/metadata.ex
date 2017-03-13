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
    %ScoutApm.Payload.Metadata{
      app_root: System.cwd(),
      unique_id: random_string(20),
      agent_version: "0.0.1",
      agent_time: DateTime.utc_now() |> DateTime.to_iso8601(),
      agent_pid: System.get_pid(),
      platform: "elixir",
    }
  end

  def random_string(length) do
    length
    |> :crypto.strong_rand_bytes
    |> Base.url_encode64
    |> binary_part(0, length)
  end
end
