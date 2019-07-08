defmodule ScoutApm.Core.AgentManager do
  use GenServer
  @behaviour ScoutApm.Collector

  def start_link() do
    options = []
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  @impl GenServer
  def init(_) do
    start_setup()
    register()
    app_metadata()
    {:ok, %{socket: nil, manifest: nil}}
  end

  def start_setup do
    GenServer.cast(__MODULE__, :setup)
  end

  def setup do
    dir = ScoutApm.Config.find(:core_agent_dir)

    if ScoutApm.Config.find(:core_agent_launch) do
      case ScoutApm.Core.verify(dir) do
        {:ok, manifest} ->
          ScoutApm.Logger.log(:info, "Found valid Scout Core Agent")

          ScoutApm.Core.Manifest.bin_path(manifest)
          |> run()

        {:error, _reason} ->
          maybe_download()
      end
    end
  end

  def maybe_download do
    dir = ScoutApm.Config.find(:core_agent_dir)

    if ScoutApm.Config.find(:core_agent_download) do
      ScoutApm.Logger.log(:info, "Failed to find valid ScoutApm Core Agent. Attempting download.")

      full_name = ScoutApm.Core.agent_full_name()
      url = ScoutApm.Core.download_url()

      with :ok <- download_binary(url, dir, "#{full_name}.tgz"),
           {:ok, manifest} <- ScoutApm.Core.verify(dir) do
        ScoutApm.Core.Manifest.bin_path(manifest)
        |> run()
      else
        _ ->
          ScoutApm.Logger.log(:warn, "Failed to start ScoutApm Core Agent")
      end
    else
      ScoutApm.Logger.log(
        :warn,
        "Not attempting to download ScoutApm Core Agent due to :core_agent_download configuration"
      )
    end
  end

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
    message = ScoutApm.Command.message(%ScoutApm.Command.Register{app: name, key: key})

    send(message)
  end

  @impl GenServer
  def handle_cast(:setup, state) do
    tcp_socket = setup()

    {:noreply, %{state | socket: tcp_socket}}
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
  def handle_cast({:send, message}, %{socket: socket} = state) when is_map(message) do
    state =
      with {:ok, encoded} <- Poison.encode(message),
           message_length <- byte_size(encoded),
           binary_length <- pad_leading(:binary.encode_unsigned(message_length, :big), 4, 0),
           :ok <- :gen_tcp.send(socket, binary_length),
           :ok <- :gen_tcp.send(socket, encoded),
           {:ok, <<message_length::big-unsigned-integer-size(32)>>} <- :gen_tcp.recv(socket, 4),
           {:ok, msg} <- :gen_tcp.recv(socket, message_length),
           {:ok, decoded_msg} <- Poison.decode(msg) do
        ScoutApm.Logger.log(
          :info,
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

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(_m, state) do
    {:noreply, state}
  end

  def pad_leading(binary, len, byte \\ 0)

  def pad_leading(binary, len, byte)
      when is_binary(binary) and is_integer(len) and is_integer(byte) and len > 0 and
             byte_size(binary) >= len,
      do: binary

  def pad_leading(binary, len, byte)
      when is_binary(binary) and is_integer(len) and is_integer(byte) and len > 0 do
    (<<byte>> |> :binary.copy(len - byte_size(binary))) <> binary
  end

  def run(bin_path) do
    ip =
      ScoutApm.Config.find(:core_agent_tcp_ip)
      |> :inet_parse.ntoa()

    port = ScoutApm.Config.find(:core_agent_tcp_port)
    socket_path = ScoutApm.Core.socket_path()

    args = ["start", "--socket", socket_path, "--daemonize", "true", "--tcp", "#{ip}:#{port}"]

    with {_, 0} <- System.cmd(bin_path, args),
         {:ok, socket} <- :gen_tcp.connect(ip, port, [{:active, false}, :binary]) do
      socket
    else
      e ->
        ScoutApm.Logger.log(
          :warn,
          "Unable to start and connect to ScoutApm Core Agent: #{inspect(e)}"
        )

        nil
    end
  end
end
