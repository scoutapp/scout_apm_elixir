defmodule ScoutApm.Core do
  def socket_path do
    socket_path = ScoutApm.Config.find(:core_agent_socket_path)

    if is_nil(socket_path) do
      dir = ScoutApm.Config.find(:core_agent_dir)

      Path.join([dir, "core-agent.sock"])
    else
      socket_path
    end
  end

  def download_url do
    url = ScoutApm.Config.find(:download_url)
    "#{url}/#{agent_full_name()}.tgz"
  end

  def agent_full_name do
    full_name = ScoutApm.Config.find(:core_agent_full_name)

    if is_nil(full_name) do
      version = ScoutApm.Config.find(:core_agent_version)
      platform_triple = platform_triple()
      "scout_apm_core-#{version}-#{platform_triple}"
    else
      full_name
    end
  end

  def platform_triple do
    "#{architecture()}-#{platform()}"
  end

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

  def architecture do
    case uname_architecture() do
      "x86_64" -> "x86_64"
      "i686" -> "i686"
      _ -> "unknown"
    end
  end

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

  def libc do
    try do
      ldd_version = System.cmd("ldd", ["--version"])

      if String.contains?(ldd_version, "musl") do
        "musl"
      else
        "gnu"
      end
    rescue
      ErlangError -> "gnu"
    end
  end

  def verify(dir) do
    manifest = ScoutApm.Core.Manifest.build_from_directory(dir)

    if manifest.valid && ScoutApm.Core.Manifest.sha256_valid?(manifest) do
      {:ok, manifest}
    else
      {:error, :invalid}
    end
  end
end
