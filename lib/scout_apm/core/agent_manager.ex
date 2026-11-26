defmodule ScoutApm.Core.AgentManager do
  use GenServer
  alias ScoutApm.Core
  alias ScoutApm.Core.Manifest
  @behaviour ScoutApm.Collector

  # TCP recv/send timeout in milliseconds
  @tcp_timeout 3_000

  # Maximum queued messages before dropping
  @max_queue_size 500

  # Consecutive errors before attempting reconnect
  @max_errors_before_reconnect 3

  # Consecutive reconnect failures before restarting the core agent process
  @max_reconnect_failures 5

  # Backoff schedule for reconnection attempts (milliseconds)
  @reconnect_backoff_ms [100, 500, 1_000, 1_000, 5_000]

  defstruct [
    :socket,
    :port,
    error_count: 0,
    reconnect_failures: 0,
    last_reconnect_at: nil,
    reconnecting: false
  ]

  @type t :: %__MODULE__{
          socket: :gen_tcp.socket() | nil,
          port: port() | nil,
          error_count: non_neg_integer(),
          reconnect_failures: non_neg_integer(),
          last_reconnect_at: integer() | nil,
          reconnecting: boolean()
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
    {:ok, %__MODULE__{}}
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
        # Send Register and app_metadata directly on the socket, not via cast.
        # setup() runs inside handle_cast(:setup), so any cast from here goes to
        # the back of the mailbox. If app requests arrive before those casts are
        # processed, a BatchCommand hits the core agent before Register, and the
        # core agent rejects it as an unregistered client.
        state = %__MODULE__{socket: socket, port: port_or_nil}
        state = send_register(state)
        state = send_app_metadata(state)
        {state.port, state.socket}
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
          ScoutApm.Logger.log(:error, "Failed to start ScoutApm Core Agent")
          {:error, :failed_to_start}
      end
    else
      ScoutApm.Logger.log(
        :info,
        "Not attempting to download ScoutApm Core Agent due to :core_agent_download configuration"
      )

      {:error, :no_file_download_disabled}
    end
  end

  @spec download_binary(String.t(), String.t(), String.t()) :: :ok | {:error, any()}
  # The directory and file name come from the agent's configuration, not external input.
  # sobelow_skip ["Traversal.FileModule"]
  def download_binary(url, directory, file_name) do
    destination = Path.join([directory, file_name])
    staging = Path.join(directory, ".#{file_name}.#{System.unique_integer([:positive])}")
    ScoutApm.Logger.log(:info, "Attempting to download ScoutApm Core Agent from: #{url}")

    # `:with_body` makes hackney 1.x return the body directly in the response
    # tuple, matching the (only) behavior of hackney 3.0+, where
    # `:hackney.body/1` no longer exists for regular requests. This form works
    # on both the 1.x and 4.x lines.
    #
    # Extract into a staging directory and rename the files into place: Linux
    # won't let a write replace a Core Agent binary that is still running
    # (:etxtbsy), but a rename can. The tarball, which `stale_download?/1`
    # treats as the marker of what's installed, is written last, so a failed
    # replacement is retried on the next start.
    try do
      with :ok <- File.mkdir_p(staging),
           {:ok, 200, _headers, body} <-
             :hackney.get(url, [], "", [:with_body, {:follow_redirect, true}]),
           :ok <- :erl_tar.extract({:binary, body}, [:compressed, {:cwd, staging}]),
           :ok <- move_into_place(staging, directory),
           :ok <- File.write(destination, body) do
        ScoutApm.Logger.log(:info, "Downloaded and extracted ScoutApm Core Agent")
        :ok
      else
        e ->
          ScoutApm.Logger.log(
            :error,
            "Failed to download and extract ScoutApm Core Agent from #{url}: #{inspect(e)}"
          )

          {:error, :failed_to_download_and_extract}
      end
    after
      File.rm_rf(staging)
    end
  end

  # The paths come from the agent's configuration and the release tarball.
  # sobelow_skip ["Traversal.FileModule"]
  defp move_into_place(staging, directory) do
    with {:ok, names} <- File.ls(staging) do
      Enum.reduce_while(names, :ok, fn name, :ok ->
        case File.rename(Path.join(staging, name), Path.join(directory, name)) do
          :ok -> {:cont, :ok}
          error -> {:halt, error}
        end
      end)
    end
  end

  @impl ScoutApm.Collector
  def send(message) when is_map(message) do
    # Check the GenServer's mailbox size from the caller's process BEFORE
    # casting. This prevents messages from accumulating in the mailbox while
    # the GenServer is blocked on TCP or reconnection. The internal check
    # in handle_cast is a second line of defense.
    case GenServer.whereis(__MODULE__) do
      nil ->
        :ok

      pid ->
        case Process.info(pid, :message_queue_len) do
          {:message_queue_len, len} when len > @max_queue_size ->
            :ok

          _ ->
            GenServer.cast(__MODULE__, {:send, message})
        end
    end
  end

  defp send_register(%{socket: nil} = state), do: state

  defp send_register(state) do
    name = ScoutApm.Config.find(:name)
    key = ScoutApm.Config.find(:key)
    hostname = ScoutApm.Config.find(:hostname)

    message =
      ScoutApm.Command.message(%ScoutApm.Command.Register{app: name, key: key, host: hostname})

    send_message(message, state)
  end

  defp send_app_metadata(%{socket: nil} = state), do: state

  defp send_app_metadata(state) do
    message =
      ScoutApm.Command.ApplicationEvent.app_metadata()
      |> ScoutApm.Command.message()

    send_message(message, state)
  end

  @impl GenServer
  @spec handle_cast(any, t()) :: {:noreply, t()}
  def handle_cast(:setup, state) do
    {port, socket} = setup()
    {:noreply, %{state | port: port, socket: socket}}
  end

  @impl GenServer
  def handle_cast({:send, _message}, %{socket: nil, reconnecting: true} = state) do
    # Reconnect already scheduled, just drop the message
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:send, _message}, %{socket: nil} = state) do
    state = maybe_reconnect(state)

    if state.socket == nil do
      ScoutApm.Logger.log(
        :debug,
        "ScoutApm Core Agent is not connected. Skipping sending event."
      )
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:send, message}, state) when is_map(message) do
    case Process.info(self(), :message_queue_len) do
      {:message_queue_len, len} when len > @max_queue_size ->
        ScoutApm.Logger.log(
          :error,
          "ScoutApm message queue full (#{len} > #{@max_queue_size}), dropping message"
        )

        {:noreply, state}

      _ ->
        state = send_message(message, state)
        {:noreply, state}
    end
  end

  @impl GenServer
  @spec handle_call(any, any(), t()) :: {:reply, any, t()}
  def handle_call({:send, _message}, _from, %{socket: nil} = state) do
    ScoutApm.Logger.log(
      :error,
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
      :error,
      "ScoutApm Core Agent exited with status #{status}"
    )

    {:noreply, %{state | port: nil, socket: nil}}
  end

  def handle_info({port, {:data, _data}}, %{port: port} = state) do
    # Discard stdout/stderr data from the core agent
    {:noreply, state}
  end

  def handle_info(:do_full_restart, state) do
    ScoutApm.Logger.log(:info, "Launching new ScoutApm Core Agent after restart delay")
    {port, socket} = setup()
    now = System.monotonic_time(:millisecond)

    if socket do
      {:noreply,
       %{
         state
         | port: port,
           socket: socket,
           error_count: 0,
           reconnect_failures: 0,
           reconnecting: false,
           last_reconnect_at: now
       }}
    else
      {:noreply,
       %{
         state
         | port: port,
           socket: nil,
           reconnect_failures: state.reconnect_failures + 1,
           reconnecting: false,
           last_reconnect_at: now
       }}
    end
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
      |> maybe_add_ca_cert()

    ScoutApm.Logger.log(:debug, "Starting Core Agent: #{bin_path} #{Enum.join(args, " ")}")

    port = launch_core_agent(bin_path, args)

    # Give the core agent time to start listening, then check if
    # the launched process exited quickly (e.g. already running).
    Process.sleep(500)
    {port, output} = drain_port(port)

    case try_connect(socket_path, ip, tcp_port) do
      {:ok, socket} ->
        {:ok, port, socket}

      nil ->
        # Collect anything the Core Agent wrote while we were connecting, so a
        # launch failure (e.g. a missing shared library) shows up in the logs.
        {_port, output} = drain_port(port, output)
        log_core_agent_output(output)
        ScoutApm.Logger.log(:error, "Unable to connect to ScoutApm Core Agent")

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

    # When stdin closes (BEAM exit or close_port): send SIGTERM, wait up to 5s,
    # then SIGKILL if the process is still alive (e.g. frozen by SIGSTOP).
    wrapper =
      ~s(#{shell_cmd} & PID=$!; cat > /dev/null; kill $PID 2>/dev/null; for i in 1 2 3 4 5; do kill -0 $PID 2>/dev/null || exit 0; sleep 1; done; kill -9 $PID 2>/dev/null; wait $PID 2>/dev/null)

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
        :error,
        "Unable to start ScoutApm Core Agent: #{inspect(e)}"
      )

      nil
  end

  defp shell_escape(arg) do
    "'" <> String.replace(arg, "'", "'\\''") <> "'"
  end

  # Consume the messages the port has sent so far. Returns the port, or nil if
  # the process already exited (consuming the exit_status message so it doesn't
  # trigger handle_info later; we don't own the running agent), along with the
  # output it wrote so a failed launch can be logged.
  @spec drain_port(port() | nil, iodata()) :: {port() | nil, iodata()}
  defp drain_port(port, output \\ [])

  defp drain_port(nil, output), do: {nil, output}

  defp drain_port(port, output) do
    receive do
      {^port, {:exit_status, status}} ->
        ScoutApm.Logger.log(
          :debug,
          "Core Agent process exited quickly with status #{status} (likely already running)"
        )

        {nil, output}

      {^port, {:data, data}} ->
        drain_port(port, [output, data])
    after
      0 -> {port, output}
    end
  end

  # Enough to show a loader or startup error without flooding the log, since
  # this runs on every failed launch attempt.
  @max_logged_output 2_000

  @spec log_core_agent_output(iodata()) :: :ok
  defp log_core_agent_output(output) do
    case output |> IO.iodata_to_binary() |> String.trim() do
      "" ->
        :ok

      text ->
        # Invalid UTF-8 would make the logger drop the whole line.
        text = if String.valid?(text), do: text, else: inspect(text)

        text =
          if String.length(text) > @max_logged_output,
            do: "..." <> String.slice(text, -@max_logged_output, @max_logged_output),
            else: text

        ScoutApm.Logger.log(:error, "ScoutApm Core Agent output: #{text}")
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
              :error,
              "Unable to connect to ScoutApm Core Agent via socket (#{inspect(socket_reason)}) or TCP (#{inspect(tcp_reason)})"
            )

            nil
        end
    end
  end

  @socket_opts [{:active, false}, :binary, {:send_timeout, @tcp_timeout}]

  @spec try_connect_socket(String.t()) :: {:ok, :gen_tcp.socket()} | {:error, atom()}
  defp try_connect_socket(socket_path) do
    case :gen_tcp.connect({:local, socket_path}, 0, @socket_opts) do
      {:ok, socket} ->
        {:ok, socket}

      _ ->
        :timer.sleep(500)
        :gen_tcp.connect({:local, socket_path}, 0, @socket_opts)
    end
  end

  @spec try_connect_tcp(charlist(), char()) :: {:ok, :gen_tcp.socket()} | {:error, atom()}
  defp try_connect_tcp(ip, port) do
    case :gen_tcp.connect(ip, port, @socket_opts) do
      {:ok, socket} ->
        {:ok, socket}

      _ ->
        :timer.sleep(500)
        :gen_tcp.connect(ip, port, @socket_opts)
    end
  end

  defp send_message(message, %{socket: socket} = state) do
    with {:ok, encoded} <- Jason.encode(message),
         message_length <- byte_size(encoded),
         binary_length <- pad_leading(:binary.encode_unsigned(message_length, :big), 4, 0),
         :ok <- :gen_tcp.send(socket, binary_length),
         :ok <- :gen_tcp.send(socket, encoded),
         {:ok, <<message_length::big-unsigned-integer-size(32)>>} <-
           :gen_tcp.recv(socket, 4, @tcp_timeout),
         {:ok, msg} <- :gen_tcp.recv(socket, message_length, @tcp_timeout),
         {:ok, decoded_msg} <- Jason.decode(msg) do
      ScoutApm.Logger.log(
        :debug,
        "Received message of length #{message_length}: #{inspect(decoded_msg)}"
      )

      %{state | error_count: 0, reconnect_failures: 0}
    else
      {:error, :timeout} ->
        ScoutApm.Logger.log(
          :warning,
          "ScoutApm Core Agent TCP recv timed out after #{@tcp_timeout}ms"
        )

        handle_send_error(socket, state)

      {:error, :closed} ->
        ScoutApm.Logger.log(
          :error,
          "ScoutApm Core Agent TCP socket closed"
        )

        handle_send_error(socket, state)

      {:error, :enotconn} ->
        ScoutApm.Logger.log(
          :error,
          "ScoutApm Core Agent TCP socket disconnected"
        )

        handle_send_error(socket, state)

      e ->
        ScoutApm.Logger.log(
          :error,
          "Error in ScoutApm Core Agent TCP socket: #{inspect(e)}"
        )

        handle_send_error(socket, state)
    end
  end

  defp handle_send_error(socket, state) do
    :gen_tcp.close(socket)
    error_count = state.error_count + 1
    state = %{state | socket: nil, error_count: error_count}

    if error_count >= @max_errors_before_reconnect do
      maybe_reconnect(state)
    else
      ScoutApm.Logger.log(
        :debug,
        "ScoutApm Core Agent error #{error_count}/#{@max_errors_before_reconnect} before reconnect attempt"
      )

      state
    end
  end

  defp maybe_reconnect(state) do
    now = System.monotonic_time(:millisecond)

    backoff_index =
      min(state.reconnect_failures, length(@reconnect_backoff_ms) - 1)

    backoff = Enum.at(@reconnect_backoff_ms, backoff_index)

    # Allow immediate reconnect on first attempt (last_reconnect_at is nil)
    elapsed = if state.last_reconnect_at, do: now - state.last_reconnect_at, else: backoff

    if elapsed < backoff do
      ScoutApm.Logger.log(
        :debug,
        "ScoutApm Core Agent reconnect backing off (#{backoff}ms between attempts)"
      )

      state
    else
      do_reconnect(state, now)
    end
  end

  defp do_reconnect(state, now) do
    # If we own the port and have exceeded max failures, kill the old process
    # and do a full setup (launch + connect). This is done asynchronously via
    # handle_info(:do_full_restart) so the GenServer stays responsive and can
    # drop incoming messages instead of letting them pile up in the mailbox.
    if state.port && state.reconnect_failures >= @max_reconnect_failures do
      ScoutApm.Logger.log(
        :error,
        "Scheduling ScoutApm Core Agent restart after #{state.reconnect_failures} reconnect failures"
      )

      close_port(state.port)
      # Schedule the full restart after giving the shell wrapper time to
      # SIGTERM → SIGKILL the hung process and release the TCP port.
      Process.send_after(self(), :do_full_restart, 6_000)

      %{state | port: nil, reconnecting: true, last_reconnect_at: now}
    else
      # Try to reconnect the socket only — don't launch a new process.
      # The existing core agent may have recovered (e.g. SIGCONT after SIGSTOP).
      ScoutApm.Logger.log(
        :info,
        "Attempting ScoutApm Core Agent socket reconnect (failure #{state.reconnect_failures + 1})"
      )

      case try_reconnect_socket() do
        {:ok, socket} ->
          # Validate the socket is actually responsive before trusting it.
          # A SIGSTOP'd agent accepts TCP connections (kernel backlog) but
          # never responds. We probe with Register and check the result
          # directly — NOT through send_message/handle_send_error, which
          # would trigger recursive reconnect logic.
          case probe_socket(socket) do
            :ok ->
              state = %{
                state
                | socket: socket,
                  error_count: 0,
                  reconnect_failures: 0,
                  last_reconnect_at: now
              }

              send_app_metadata(state)

            :error ->
              :gen_tcp.close(socket)
              %{state | reconnect_failures: state.reconnect_failures + 1, last_reconnect_at: now}
          end

        nil ->
          %{state | reconnect_failures: state.reconnect_failures + 1, last_reconnect_at: now}
      end
    end
  end

  # Send Register on the socket and verify we get a response. Returns :ok or :error.
  # This avoids the send_message → handle_send_error → maybe_reconnect recursion.
  defp probe_socket(socket) do
    name = ScoutApm.Config.find(:name)
    key = ScoutApm.Config.find(:key)
    hostname = ScoutApm.Config.find(:hostname)

    message =
      ScoutApm.Command.message(%ScoutApm.Command.Register{app: name, key: key, host: hostname})

    with {:ok, encoded} <- Jason.encode(message),
         message_length <- byte_size(encoded),
         binary_length <- pad_leading(:binary.encode_unsigned(message_length, :big), 4, 0),
         :ok <- :gen_tcp.send(socket, binary_length),
         :ok <- :gen_tcp.send(socket, encoded),
         {:ok, <<resp_len::big-unsigned-integer-size(32)>>} <-
           :gen_tcp.recv(socket, 4, @tcp_timeout),
         {:ok, _msg} <- :gen_tcp.recv(socket, resp_len, @tcp_timeout) do
      ScoutApm.Logger.log(:info, "ScoutApm Core Agent socket probe succeeded (Register accepted)")
      :ok
    else
      _ ->
        ScoutApm.Logger.log(:warning, "ScoutApm Core Agent socket probe failed (unresponsive)")
        :error
    end
  end

  # Try to connect to an already-running core agent without launching a new one.
  defp try_reconnect_socket do
    ip =
      ScoutApm.Config.find(:core_agent_tcp_ip)
      |> :inet_parse.ntoa()

    tcp_port = ScoutApm.Config.find(:core_agent_tcp_port)
    socket_path = Core.socket_path()

    try_connect(socket_path, ip, tcp_port)
  end

  @spec verify_or_download :: {:ok, map()} | {:error, any()}
  def verify_or_download do
    dir = ScoutApm.Config.find(:core_agent_dir)

    case Core.verify(dir) do
      {:ok, manifest} ->
        if stale_download?(dir) do
          replace_stale_download(dir)
        else
          ScoutApm.Logger.log(:info, "Found valid Scout Core Agent")
          {:ok, manifest}
        end

      {:error, _reason} ->
        maybe_download()
    end
  end

  # `download_binary/3` keeps the tarball next to the extracted agent, named
  # after `Core.agent_full_name()`. If it's missing, the agent in the directory
  # was downloaded for another version or platform triple (e.g. the glibc build
  # an earlier release fetched into the default /tmp/scout_apm_core), so fetch
  # the current one. Agents placed by hand with downloads disabled are kept.
  @spec stale_download?(String.t()) :: boolean()
  # The directory comes from the agent's configuration, not external input.
  # sobelow_skip ["Traversal.FileModule"]
  defp stale_download?(dir) do
    if ScoutApm.Config.find(:core_agent_download),
      do: not File.exists?(Path.join(dir, "#{Core.agent_full_name()}.tgz")),
      else: false
  end

  @spec replace_stale_download(String.t()) :: {:ok, map()} | {:error, any()}
  defp replace_stale_download(dir) do
    ScoutApm.Logger.log(
      :info,
      "Found a Scout Core Agent that doesn't match #{Core.agent_full_name()}. Downloading it."
    )

    case maybe_download() do
      {:ok, new_manifest} ->
        {:ok, new_manifest}

      {:error, _reason} ->
        # Keep the agent that was already there rather than running none,
        # unless a failed extraction left the directory invalid.
        Core.verify(dir)
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

  @spec maybe_add_ca_cert(list(String.t())) :: list(String.t())
  defp maybe_add_ca_cert(args) do
    case ScoutApm.Config.find(:core_agent_ca_cert) do
      nil ->
        args

      path when is_binary(path) ->
        args ++ ["--ca-cert", path]
    end
  end
end
