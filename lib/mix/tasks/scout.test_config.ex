defmodule Mix.Tasks.Scout.TestConfig do
  use Mix.Task

  @moduledoc """
  Checks application configuration and core agent communication
  """

  def run(args) do
    unless "--no-compile" in args do
      Mix.Project.compile(args)
    end

    Application.ensure_all_started(:scout_apm)

    check_config()
    check_agent()
  end

  defp check_config do
    name = ScoutApm.Config.find(:name)
    key = ScoutApm.Config.find(:key)
    monitor = ScoutApm.Config.find(:monitor)

    Mix.shell().info("Configuration:")
    Mix.shell().info("Name: #{inspect(name)}")
    Mix.shell().info("Key: #{inspect(key)}")
    Mix.shell().info("Monitor: #{inspect(monitor)}")

    if not is_binary(name) || not is_binary(key) do
      Mix.raise("Scout :name and :key configuration is required to profile")
    end

    if not monitor do
      Mix.raise("Scout :monitor configuration must be true to profile")
    end
  end

  defp check_agent do
    message =
      ScoutApm.Command.ApplicationEvent.app_metadata()
      |> ScoutApm.Command.message()

    case GenServer.call(ScoutApm.Core.AgentManager, {:send, message}) do
      %{socket: socket} when not is_nil(socket) ->
        Mix.shell().info("Successfully connected to Scout Agent")

      _ ->
        Mix.raise("Could not connect to Scout Agent")
    end
  end
end
