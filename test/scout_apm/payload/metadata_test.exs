defmodule ScoutApm.Payload.MetadataTest do
  use ExUnit.Case, async: true

  alias ScoutApm.Payload.Metadata

  describe "new/1" do
    test "creating a metadata struct with a timestamp" do
      {:ok, app_root} = File.cwd()
      timestamp = DateTime.utc_now()

      assert %ScoutApm.Payload.Metadata{
               agent_version: "0.4.9",
               app_root: ^app_root,
               payload_version: 1,
               platform: "elixir"
             } = Metadata.new(timestamp)
    end
  end
end
