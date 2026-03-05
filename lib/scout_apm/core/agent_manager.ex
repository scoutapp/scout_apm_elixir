defmodule ScoutApm.Core.AgentManager do
  use GenServer
  alias ScoutApm.Core
  alias ScoutApm.Core.Manifest
  @behaviour ScoutApm.Collector

  defstruct [:socket, :port]

  @type t :: %__MODULE__{
          socket: :gen_tcp.socket() | nil,
          port: port() | nil
        }

  def start_link(_) do
    options = []
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  @impl GenServer
  @spec init(any) :: {:ok, t()}
  def init(_) do
    Process.flag(:trap_exit, true)
    start_setup()
    {:ok, %__MODULE__{socket: nil, port: nil}}
  end

  def start_setup do
    GenServer.cast(__MODULE__, :setup)
  end

  @spec setup :: {port() | nil, :gen_tcp.socket() | nil}
  def setup do
    enabled = ScoutApm.Config.find(:monitor)
    core_agent_launch = ScoutApm.Config.find(:core_agent_launch)
    key = ScoutApm.Config.find(:key)

    if enabled && core_agent_launch && key do
      with {:ok, manifest} <- verify_or_download(),
           bin_path when is_binary(bin_path) <- Manifest.bin_path(manifest),
           {:ok, port_or_nil, socket} <- run(bin_path) do
        register()
        app_metadata()
        {port_or_nil, socket}
      else
        _e ->
          {nil, nil}
      end
    else
      {nil, nil}
    end
  end

  @spec maybe_download :: {:ok, map()} | {:error, any()}
  def maybe_download do
    if ScoutApm.Config.find(:core_agent_download) do
      ScoutApm.Logger.log(:info, "Failed to find valid ScoutApm Core Agent. Attempting download.")

      full_name = Core.agent_full_name()
      url = Core.download_url()
      dir = ScoutApm.Config.find(:core_agent_dir)

      with :ok <- download_binary(url, dir, "#{full_name}.tgz"),
           {:ok, manifest} <- Core.verify(dir) do
        ScoutApm.Logger.log(:debug, "Successfully downloaded and verified ScoutApm Core Agent")
        {:ok, manifest}
      else
        _ ->
          ScoutApm.Logger.log(:warning, "Failed to start ScoutApm Core Agent")
          {:error, :failed_to_start}
      end
    else
      ScoutApm.Logger.log(
        :warning,
        "Not attempting to download ScoutApm Core Agent due to :core_agent_download configuration"
      )

      {:error, :no_file_download_disabled}
    end
  end

  @spec download_binary(String.t(), String.t(), String.t()) :: :ok | {:error, any()}
  def download_binary(url, directory, file_name) do
    destination = Path.join([directory, file_name])
    ScoutApm.Logger.log(:info, "Attempting to download ScoutApm Core Agent from: #{url}")

    with :ok <- File.mkdir_p(directory),
         {:ok, 200, _headers, client_ref} <- :hackney.get(url, [], "", follow_redirect: true),
         {:ok, body} <- :hackney.body(client_ref),
         :ok <- File.write(destination, body),
         :ok <- :erl_tar.extract(destination, [:compressed, {:cwd, directory}]) do
      ScoutApm.Logger.log(:info, "Downloaded and extracted ScoutApm Core Agent")
      :ok
    else
      e ->
        ScoutApm.Logger.log(
          :warning,
          "Failed to download and extract ScoutApm Core Agent from #{url}: #{inspect(e)}"
        )

        {:error, :failed_to_download_and_extract}
    end
  end

  @impl ScoutApm.Collector
  def send(message) when is_map(message) do
    GenServer.cast(__MODULE__, {:send, message})
  end

  def app_metadata do
    message =
      ScoutApm.Command.ApplicationEvent.app_metadata()
      |> ScoutApm.Command.message()

    send(message)
  end

  def register do
    name = ScoutApm.Config.find(:name)
    key = ScoutApm.Config.find(:key)
    hostname = ScoutApm.Config.find(:hostname)

    message =
      ScoutApm.Command.message(%ScoutApm.Command.Register{app: name, key: key, host: hostname})

    send(message)
  end

  @impl GenServer
  @spec handle_cast(any, t()) :: {:noreply, t()}
  def handle_cast(:setup, state) do
    {port, socket} = setup()
    {:noreply, %{state | port: port, socket: socket}}
  end

  @impl GenServer
  def handle_cast({:send, _message}, %{socket: nil} = state) do
    ScoutApm.Logger.log(
      :warning,
      "ScoutApm Core Agent is not connected. Skipping sending event."
    )

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:send, message}, state) when is_map(message) do
    state = send_message(message, state)
    {:noreply, state}
  end

  @impl GenServer
  @spec handle_call(any, any(), t()) :: {:reply, any, t()}
  def handle_call({:send, _message}, _from, %{socket: nil} = state) do
    ScoutApm.Logger.log(
      :warning,
      "ScoutApm Core Agent is not connected. Skipping sending event."
    )

    {:reply, state, state}
  end

  @impl GenServer
  def handle_call({:send, message}, _from, state) when is_map(message) do
    state = send_message(message, state)
    {:reply, state, state}
  end

  @impl GenServer
  @spec handle_info(any, t()) :: {:noreply, t()}
  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    ScoutApm.Logger.log(
      :warning,
      "ScoutApm Core Agent exited with status #{status}"
    )

    {:noreply, %{state | port: nil, socket: nil}}
  end

  def handle_info({port, {:data, _data}}, %{port: port} = state) do
    # Discard stdout/stderr data from the core agent
    {:noreply, state}
  end

  def handle_info(_m, state) do
    {:noreply, state}
  end

  @impl GenServer
  def terminate(_reason, %{port: port} = state) do
    if port != nil do
      ScoutApm.Logger.log(:info, "Shutting down ScoutApm Core Agent")
      close_port(port)
    end

    if state.socket != nil do
      :gen_tcp.close(state.socket)
    end

    :ok
  end

  defp close_port(port) do
    try do
      Port.close(port)
    rescue
      ArgumentError -> :ok
    end
  end

  @spec pad_leading(binary(), integer(), integer()) :: binary()
  def pad_leading(binary, len, byte \\ 0)

  def pad_leading(binary, len, byte)
      when is_binary(binary) and is_integer(len) and is_integer(byte) and len > 0 and
             byte_size(binary) >= len,
      do: binary

  def pad_leading(binary, len, byte)
      when is_binary(binary) and is_integer(len) and is_integer(byte) and len > 0 do
    (<<byte>> |> :binary.copy(len - byte_size(binary))) <> binary
  end

  @spec run(String.t()) :: {:ok, port() | nil, :gen_tcp.socket()} | nil
  def run(bin_path) do
    ip =
      ScoutApm.Config.find(:core_agent_tcp_ip)
      |> :inet_parse.ntoa()

    tcp_port = ScoutApm.Config.find(:core_agent_tcp_port)
    socket_path = Core.socket_path()

    args = [
      "start",
      "--socket",
      socket_path,
      "--daemonize",
      "false",
      "--tcp",
      "#{ip}:#{tcp_port}"
    ]

    args =
      args
      |> maybe_add_log_level()
      |> maybe_add_log_file()
      |> maybe_add_config_file()

    ScoutApm.Logger.log(:debug, "Starting Core Agent: #{bin_path} #{Enum.join(args, " ")}")

    port = launch_core_agent(bin_path, args)

    # Give the core agent time to start listening, then check if
    # the launched process exited quickly (e.g. already running).
    Process.sleep(500)
    port = drain_port_exit(port)

    case try_connect(socket_path, ip, tcp_port) do
      {:ok, socket} ->
        {:ok, port, socket}

      nil ->
        ScoutApm.Logger.log(:warning, "Unable to connect to ScoutApm Core Agent")

        if port do
          close_port(port)
        end

        nil
    end
  end

  # Launch the core agent through a shell wrapper that monitors stdin.
  # When the BEAM exits for ANY reason (graceful shutdown, ctrl-c abort,
  # crash), the stdin pipe closes, `cat` returns, and the wrapper kills
  # the core agent. This ensures cleanup even when terminate/2 is skipped.
  defp launch_core_agent(bin_path, args) do
    shell_cmd = Enum.map_join([bin_path | args], " ", &shell_escape/1)

    wrapper =
      ~s(#{shell_cmd} & PID=$!; cat > /dev/null; kill $PID 2>/dev/null; wait $PID 2>/dev/null)

    Port.open({:spawn_executable, ~c"/bin/sh"}, [
      :binary,
      :exit_status,
      :stderr_to_stdout,
      :use_stdio,
      args: ["-c", wrapper]
    ])
  rescue
    e ->
      ScoutApm.Logger.log(
        :warning,
        "Unable to start ScoutApm Core Agent: #{inspect(e)}"
      )

      nil
  end

  defp shell_escape(arg) do
    "'" <> String.replace(arg, "'", "'\\''") <> "'"
  end

  # Check if the port process already exited. If so, consume the
  # exit_status message so it doesn't trigger handle_info later,
  # and return nil (we don't own the running agent).
  defp drain_port_exit(nil), do: nil

  defp drain_port_exit(port) do
    receive do
      {^port, {:exit_status, _status}} ->
        ScoutApm.Logger.log(
          :debug,
          "Core Agent process exited quickly (likely already running)"
        )

        nil

      {^port, {:data, _data}} ->
        drain_port_exit(port)
    after
      0 -> port
    end
  end

  @spec try_connect(String.t(), charlist(), char()) :: {:ok, :gen_tcp.socket()} | nil
  defp try_connect(socket_path, ip, port) do
    case try_connect_socket(socket_path) do
      {:ok, socket} ->
        ScoutApm.Logger.log(:debug, "Connected to Core Agent via Unix socket")
        {:ok, socket}

      {:error, socket_reason} ->
        ScoutApm.Logger.log(
          :debug,
          "Unix socket connection failed (#{inspect(socket_reason)}), trying TCP"
        )

        case try_connect_tcp(ip, port) do
          {:ok, socket} ->
            ScoutApm.Logger.log(:debug, "Connected to Core Agent via TCP")
            {:ok, socket}

          {:error, tcp_reason} ->
            ScoutApm.Logger.log(
              :warning,
              "Unable to connect to ScoutApm Core Agent via socket (#{inspect(socket_reason)}) or TCP (#{inspect(tcp_reason)})"
            )

            nil
        end
    end
  end

  @spec try_connect_socket(String.t()) :: {:ok, :gen_tcp.socket()} | {:error, atom()}
  defp try_connect_socket(socket_path) do
    case :gen_tcp.connect({:local, socket_path}, 0, [{:active, false}, :binary]) do
      {:ok, socket} ->
        {:ok, socket}

      _ ->
        :timer.sleep(500)
        :gen_tcp.connect({:local, socket_path}, 0, [{:active, false}, :binary])
    end
  end

  @spec try_connect_tcp(charlist(), char()) :: {:ok, :gen_tcp.socket()} | {:error, atom()}
  defp try_connect_tcp(ip, port) do
    case :gen_tcp.connect(ip, port, [{:active, false}, :binary]) do
      {:ok, socket} ->
        {:ok, socket}

      _ ->
        :timer.sleep(500)
        :gen_tcp.connect(ip, port, [{:active, false}, :binary])
    end
  end

  defp send_message(message, %{socket: socket} = state) do
    with {:ok, encoded} <- Jason.encode(message),
         message_length <- byte_size(encoded),
         binary_length <- pad_leading(:binary.encode_unsigned(message_length, :big), 4, 0),
         :ok <- :gen_tcp.send(socket, binary_length),
         :ok <- :gen_tcp.send(socket, encoded),
         {:ok, <<message_length::big-unsigned-integer-size(32)>>} <- :gen_tcp.recv(socket, 4),
         {:ok, msg} <- :gen_tcp.recv(socket, message_length),
         {:ok, decoded_msg} <- Jason.decode(msg) do
      ScoutApm.Logger.log(
        :debug,
        "Received message of length #{message_length}: #{inspect(decoded_msg)}"
      )

      state
    else
      {:error, :closed} ->
        :gen_tcp.close(socket)

        ScoutApm.Logger.log(
          :warning,
          "ScoutApm Core Agent TCP socket closed. Attempting to reconnect."
        )

        reconnect(state)

      {:error, :enotconn} ->
        :gen_tcp.close(socket)

        ScoutApm.Logger.log(
          :warning,
          "ScoutApm Core Agent TCP socket disconnected. Attempting to reconnect."
        )

        reconnect(state)

      e ->
        :gen_tcp.close(socket)

        ScoutApm.Logger.log(
          :warning,
          "Error in ScoutApm Core Agent TCP socket: #{inspect(e)}. Attempting to reconnect."
        )

        reconnect(state)
    end
  end

  defp reconnect(state) do
    {port, socket} = setup()
    %{state | port: port, socket: socket}
  end

  @spec verify_or_download :: {:ok, map()} | {:error, any()}
  def verify_or_download do
    dir = ScoutApm.Config.find(:core_agent_dir)

    case Core.verify(dir) do
      {:ok, manifest} ->
        ScoutApm.Logger.log(:info, "Found valid Scout Core Agent")
        {:ok, manifest}

      {:error, _reason} ->
        maybe_download()
    end
  end

  @spec maybe_add_log_level(list(String.t())) :: list(String.t())
  defp maybe_add_log_level(args) do
    case ScoutApm.Config.find(:core_agent_log_level) do
      nil ->
        args

      level when is_binary(level) ->
        args ++ ["--log-level", level]
    end
  end

  @spec maybe_add_log_file(list(String.t())) :: list(String.t())
  defp maybe_add_log_file(args) do
    case ScoutApm.Config.find(:core_agent_log_file) do
      nil ->
        args

      path when is_binary(path) ->
        expanded_path = Path.expand(path)
        args ++ ["--log-file", expanded_path]
    end
  end

  @spec maybe_add_config_file(list(String.t())) :: list(String.t())
  defp maybe_add_config_file(args) do
    case ScoutApm.Config.find(:core_agent_config_file) do
      nil ->
        args

      path when is_binary(path) ->
        expanded_path = Path.expand(path)
        args ++ ["--config-file", expanded_path]
    end
  end
end
