defmodule ScoutApm.Core do
  @spec socket_path :: String.t()
  def socket_path do
    socket_path = ScoutApm.Config.find(:core_agent_socket_path)

    if is_nil(socket_path) do
      dir = ScoutApm.Config.find(:core_agent_dir)

      Path.join([dir, "scout-agent.sock"])
    else
      socket_path
    end
  end

  @spec download_url :: String.t()
  def download_url do
    url = ScoutApm.Config.find(:download_url)
    "#{url}/#{agent_full_name()}.tgz"
  end

  @spec agent_full_name :: String.t()
  def agent_full_name do
    full_name = ScoutApm.Config.find(:core_agent_full_name)

    if is_nil(full_name) do
      version = ScoutApm.Config.find(:core_agent_version)

      platform_triple =
        case ScoutApm.Config.find(:core_agent_triple) do
          triple when is_binary(triple) -> triple
          nil -> platform_triple()
        end

      "scout_apm_core-#{version}-#{platform_triple}"
    else
      full_name
    end
  end

  @spec platform_triple :: String.t()
  def platform_triple do
    "#{architecture()}-#{platform()}"
  end

  @spec platform :: String.t()
  def platform do
    case :os.type() do
      {:unix, :darwin} ->
        "apple-darwin"

      {:unix, _} ->
        libc = libc()
        "unknown-linux-#{libc}"

      _ ->
        "unknown"
    end
  end

  @spec architecture :: String.t()
  def architecture do
    case uname_architecture() do
      "x86_64" -> "x86_64"
      "i686" -> "i686"
      _ -> "unknown"
    end
  end

  @spec uname_architecture :: String.t()
  def uname_architecture do
    try do
      case System.cmd("uname", ["-m"]) do
        {arch, 0} -> String.trim(arch)
        _ -> "unknown"
      end
    rescue
      ErlangError -> "unknown"
    end
  end

  @spec libc :: String.t()
  def libc do
    case File.read("/etc/alpine-release") do
      {:ok, _} -> "musl"
      {:error, _} -> detect_libc_from_ldd()
    end
  end

  @spec detect_libc_from_ldd :: String.t()
  def detect_libc_from_ldd do
    try do
      {ldd_version, 0} = System.cmd("ldd", ["--version"])

      if String.contains?(ldd_version, "musl") do
        "musl"
      else
        "gnu"
      end
    rescue
      ErlangError -> "gnu"
    end
  end

  @spec verify(String.t()) :: {:ok, ScoutApm.Core.Manifest.t()} | {:error, :invalid}
  def verify(dir) do
    manifest = ScoutApm.Core.Manifest.build_from_directory(dir)

    if manifest.valid && ScoutApm.Core.Manifest.sha256_valid?(manifest) do
      {:ok, manifest}
    else
      {:error, :invalid}
    end
  end
end
