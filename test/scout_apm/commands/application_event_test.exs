defmodule ScoutApm.Command.ApplicationEventTest do
  use ExUnit.Case

  alias ScoutApm.Command.ApplicationEvent

  describe "app_metadata/0" do
    test "returns an ApplicationEvent struct with scout.metadata event_type" do
      result = ApplicationEvent.app_metadata()

      assert %ApplicationEvent{} = result
      assert result.event_type == "scout.metadata"
      assert is_map(result.event_value)
    end

    test "includes language info" do
      %{event_value: metadata} = ApplicationEvent.app_metadata()

      assert metadata.language == "elixir"
      assert is_binary(metadata.language_version)
      assert metadata.language_version =~ ~r/^\d+\.\d+\.\d+/
      assert metadata.language_version =~ "OTP"
      assert metadata.language_version =~ "ERTS"
    end

    test "includes version matching System.version()" do
      %{event_value: metadata} = ApplicationEvent.app_metadata()

      assert metadata.version == System.version()
    end

    test "includes server_time in ISO 8601 format" do
      %{event_value: metadata} = ApplicationEvent.app_metadata()

      assert is_binary(metadata.server_time)
      assert metadata.server_time =~ ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/
      assert String.ends_with?(metadata.server_time, "Z")
    end

    test "includes libraries as list of [name, version] pairs" do
      %{event_value: metadata} = ApplicationEvent.app_metadata()

      assert is_list(metadata.libraries)
      assert length(metadata.libraries) > 0

      # Each library should be a [name, version] list
      Enum.each(metadata.libraries, fn lib ->
        assert is_list(lib)
        assert length(lib) == 2
        [name, version] = lib
        assert is_binary(name)
        assert is_binary(version)
      end)

      # Should include elixir itself
      assert Enum.any?(metadata.libraries, fn [name, _] -> name == "elixir" end)
    end

    test "includes application_root as current working directory" do
      %{event_value: metadata} = ApplicationEvent.app_metadata()

      {:ok, cwd} = File.cwd()
      assert metadata.application_root == cwd
    end

    test "detects framework when loaded" do
      %{event_value: metadata} = ApplicationEvent.app_metadata()

      # Framework detection should return a string (may be empty if no framework loaded)
      assert is_binary(metadata.framework)
      assert is_binary(metadata.framework_version)

      # If Phoenix is loaded, should detect it
      if Application.loaded_applications()
         |> Enum.any?(fn {name, _, _} -> name == :phoenix end) do
        assert metadata.framework == "Phoenix"
        assert metadata.framework_version =~ ~r/^\d+\.\d+/
      end
    end

    test "detects app server when loaded" do
      %{event_value: metadata} = ApplicationEvent.app_metadata()

      assert is_binary(metadata.app_server)

      # If Cowboy or Bandit is loaded, should detect it
      loaded_apps = Application.loaded_applications() |> Enum.map(fn {name, _, _} -> name end)

      cond do
        :bandit in loaded_apps -> assert metadata.app_server == "Bandit"
        :cowboy in loaded_apps -> assert metadata.app_server == "Cowboy"
        true -> assert metadata.app_server == ""
      end
    end

    test "detects database adapter when loaded" do
      %{event_value: metadata} = ApplicationEvent.app_metadata()

      assert is_binary(metadata.database_adapter)

      # If a known adapter is loaded, should detect it
      loaded_apps = Application.loaded_applications() |> Enum.map(fn {name, _, _} -> name end)

      cond do
        :postgrex in loaded_apps ->
          assert metadata.database_adapter == "PostgreSQL"

        :myxql in loaded_apps ->
          assert metadata.database_adapter == "MySQL"

        :tds in loaded_apps ->
          assert metadata.database_adapter == "MSSQL"

        :exqlite in loaded_apps or :ecto_sqlite3 in loaded_apps ->
          assert metadata.database_adapter == "SQLite"

        true ->
          assert metadata.database_adapter == ""
      end
    end

    test "includes hostname" do
      %{event_value: metadata} = ApplicationEvent.app_metadata()

      assert is_binary(metadata.hostname)
    end

    test "includes git_sha" do
      %{event_value: metadata} = ApplicationEvent.app_metadata()

      # git_sha can be empty string if not in a git repo
      assert is_binary(metadata.git_sha)
    end

    test "includes source as process identifier" do
      result = ApplicationEvent.app_metadata()

      assert is_binary(result.source)
      assert result.source =~ ~r/#PID</
    end
  end
end
