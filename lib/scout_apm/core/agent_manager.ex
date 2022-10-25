defmodule ScoutApm.Core.AgentManager do
  use GenServer
  alias ScoutApm.Core
  alias ScoutApm.Core.Manifest
  @behaviour ScoutApm.Collector

  defstruct [:socket]

  @type t :: %__MODULE__{
          socket: :gen_tcp.socket() | nil
        }

  def start_link(_) do
    options = []
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  @impl GenServer
  @spec init(any) :: {:ok, t()}
  def init(_) do
    start_setup()
    {:ok, %__MODULE__{socket: nil}}
  end

  def start_setup do
    GenServer.cast(__MODULE__, :setup)
  end

  @spec setup :: :gen_tcp.socket() | nil
  def setup do
    enabled = ScoutApm.Config.find(:monitor)
    core_agent_launch = ScoutApm.Config.find(:core_agent_launch)
    key = ScoutApm.Config.find(:key)

    if enabled && core_agent_launch && key do
      with {:ok, manifest} <- verify_or_download(),
           bin_path when is_binary(bin_path) <- Manifest.bin_path(manifest),
           {:ok, socket} <- run(bin_path) do
        register()
        app_metadata()
        socket
      else
        _e ->
          nil
      end
    else
      nil
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
          ScoutApm.Logger.log(:warn, "Failed to start ScoutApm Core Agent")
          {:error, :failed_to_start}
      end
    else
      ScoutApm.Logger.log(
        :warn,
        "Not attempting to download ScoutApm Core Agent due to :core_agent_download configuration"
      )

      {:error, :no_file_download_disabled}
    end
  end

  @spec download_binary(String.t(), String.t(), String.t()) :: :ok | {:error, any()}
  def download_binary(url, directory, file_name) do
    destination = Path.join([directory, file_name])

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
          :warn,
          "Failed to download and extract ScoutApm Core Agent: #{inspect(e)}"
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
    {:noreply, %{state | socket: setup()}}
  end

  @impl GenServer
  def handle_cast({:send, _message}, %{socket: nil} = state) do
    ScoutApm.Logger.log(
      :warn,
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
      :warn,
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
  def handle_info(_m, state) do
    {:noreply, state}
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

  @spec run(String.t()) :: {:ok, :gen_tcp.socket()} | nil
  def run(bin_path) do
    ip =
      ScoutApm.Config.find(:core_agent_tcp_ip)
      |> :inet_parse.ntoa()

    port = ScoutApm.Config.find(:core_agent_tcp_port)
    socket_path = Core.socket_path()

    args = ["start", "--socket", socket_path, "--daemonize", "true", "--tcp", "#{ip}:#{port}"]

    with {_, 0} <- System.cmd(bin_path, args),
         {:ok, socket} <- try_connect_twice(ip, port) do
      {:ok, socket}
    else
      e ->
        ScoutApm.Logger.log(
          :warn,
          "Unable to start and connect to ScoutApm Core Agent: #{inspect(e)}"
        )

        nil
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
        Port.close(socket)

        ScoutApm.Logger.log(
          :warn,
          "ScoutApm Core Agent TCP socket closed. Attempting to reconnect."
        )

        %{state | socket: setup()}

      {:error, :enotconn} ->
        Port.close(socket)

        ScoutApm.Logger.log(
          :warn,
          "ScoutApm Core Agent TCP socket disconnected. Attempting to reconnect."
        )

        %{state | socket: setup()}

      e ->
        Port.close(socket)

        ScoutApm.Logger.log(
          :warn,
          "Error in ScoutApm Core Agent TCP socket: #{inspect(e)}. Attempting to reconnect."
        )

        %{state | socket: setup()}
    end
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

  @spec try_connect_twice(charlist(), char()) ::
          {:ok, :gen_tcp.socket()} | {:error, atom()}
  defp try_connect_twice(ip, port) do
    case :gen_tcp.connect(ip, port, [{:active, false}, :binary]) do
      {:ok, socket} ->
        {:ok, socket}

      _ ->
        :timer.sleep(500)
        :gen_tcp.connect(ip, port, [{:active, false}, :binary])
    end
  end
end
