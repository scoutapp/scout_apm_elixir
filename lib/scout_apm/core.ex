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
    triple = "#{architecture()}-#{platform()}"
    # For Apple Silicon (M1/M2/M3), use x86_64 binary via Rosetta 2
    # since there's no native ARM build of the Core Agent.
    # No native ARM build of the Core Agent exists yet.
    apple_darwin_aarch64_override(triple)
  end

  defp apple_darwin_aarch64_override("aarch64-apple-darwin"), do: "x86_64-apple-darwin"
  defp apple_darwin_aarch64_override(triple), do: triple

  @spec platform :: String.t()
  def platform do
    case :os.type() do
      {:unix, :darwin} ->
        "apple-darwin"

      # Always use the statically linked musl build on Linux, on glibc systems
      # too. The glibc ("gnu") builds link against whatever glibc they were
      # built with, so a build-environment change can raise the minimum glibc
      # and stop the Core Agent from starting on older distributions (Core
      # Agent v1.6.0's gnu builds need glibc 2.38, which Debian 12 and
      # Ubuntu 22.04 don't have). The musl build has no such dependency. The
      # Python and Node agents made the same choice. Set `core_agent_triple`
      # to override.
      {:unix, _} ->
        "unknown-linux-musl"

      _ ->
        "unknown"
    end
  end

  @spec architecture :: String.t()
  def architecture do
    case uname_architecture() do
      "x86_64" -> "x86_64"
      "i686" -> "i686"
      "arm64" -> "aarch64"
      "aarch64" -> "aarch64"
      other -> other
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
