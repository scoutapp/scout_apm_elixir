defmodule ScoutApm.Core.Manifest do
  defstruct [:version, :bin_version, :bin_name, :sha256, :valid, :directory]
  alias __MODULE__

  @type t :: %__MODULE__{
          version: String.t() | nil,
          bin_version: String.t() | nil,
          bin_name: String.t() | nil,
          sha256: String.t() | nil,
          valid: boolean,
          directory: String.t()
        }

  @spec build_from_directory(String.t(), String.t()) :: t()
  def build_from_directory(directory, file \\ "manifest.json") do
    manifest_path = Path.join([directory, file])

    with {:ok, binary} <- File.read(manifest_path),
         {:ok, json} <- Jason.decode(binary),
         {:ok, version} <- Map.fetch(json, "version"),
         {:ok, bin_version} <- Map.fetch(json, "core_agent_version"),
         {:ok, bin_name} <- Map.fetch(json, "core_agent_binary"),
         {:ok, sha} <- Map.fetch(json, "core_agent_binary_sha256") do
      %__MODULE__{
        directory: directory,
        version: version,
        bin_version: bin_version,
        bin_name: bin_name,
        sha256: sha,
        valid: true
      }
    else
      _ ->
        %__MODULE__{
          directory: directory,
          valid: false
        }
    end
  end

  @spec bin_path(t()) :: String.t()
  def bin_path(%Manifest{directory: dir, bin_name: bin}), do: Path.join([dir, bin])

  @spec sha256_valid?(t()) :: boolean | :error
  def sha256_valid?(%Manifest{valid: true} = manifest) do
    bin_path = Manifest.bin_path(manifest)

    with {:ok, content} <- File.read(bin_path),
         hash <- :crypto.hash(:sha256, content),
         encoded <- Base.encode16(hash, case: :lower) do
      manifest.sha256 == encoded
    else
      _ ->
        ScoutApm.Logger.log(:debug, "Core Agent verification failed due to SHA mismatch")
        :error
    end
  end
end
