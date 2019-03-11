defmodule ScoutApm.Payload.MetadataTest do
  use ExUnit.Case, async: true

  alias ScoutApm.Payload.Metadata

  describe "new/1" do
    test "creating a metadata struct with a timestamp" do
      {:ok, app_root} = File.cwd()
      {:ok, timestamp} = NaiveDateTime.new(2018, 1, 1, 1, 5, 3)
      agent_version = Application.spec(:scout_apm)[:vsn] |> to_string()

      assert %ScoutApm.Payload.Metadata{
               agent_version: ^agent_version,
               app_root: ^app_root,
               payload_version: 1,
               agent_time: "2018-01-01T01:05:03Z",
               platform: "elixir"
             } = Metadata.new(timestamp)
    end
  end
end
