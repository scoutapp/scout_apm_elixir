defmodule ScoutApm.Mixfile do
  use Mix.Project

  def project do
    [
      app: :scout_apm,
      version: "2.0.0",
      elixir: "~> 1.14",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      description: description(),
      package: package()
    ]
  end

  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [
      extra_applications: [
        :logger
      ],
      mod: {ScoutApm.Application, []}
    ]
  end

  defp deps do
    [
      {:plug, "~> 1.0"},
      {:jason, "~> 1.0"},

      # Compatible with both the hackney 1.x and 4.x lines. The 4.0.1 floor
      # excludes hackney 4.0.0, which is affected by the CVEs fixed in 4.0.1
      # (e.g. CVE-2026-47066/47067/47071/47077). Note: hackney 4.x requires
      # Erlang/OTP 27+; on older OTP releases, pin {:hackney, "~> 1.24"} in
      # your application.
      {:hackney, "~> 1.0 or ~> 4.0 and >= 4.0.1"},
      {:approximate_histogram, "~> 0.1.1"},
      {:telemetry, "~> 1.0"},

      # Optional Phoenix instrumentation dependencies
      {:phoenix, "~> 1.6", optional: true},
      {:phoenix_html, "~> 3.0 or ~> 4.0", optional: true},
      {:phoenix_live_view, "~> 0.18 or ~> 1.0", optional: true},

      # Dev & Testing Deps
      {:ex_doc, ">= 0.0.0", only: [:dev]},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:bypass, "~> 2.1", only: [:test]}
    ]
  end

  defp description() do
    """
    ScoutAPM agent for Phoenix & Elixir projects. For more information, visit https://www.scoutapm.com/agents/elixir-phoenix-monitoring.
    """
  end

  defp package do
    # These are the default files included in the package
    [
      name: :scout_apm,
      files: ["lib", "priv", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Scout Team"],
      licenses: ["Scout Software Agent License"],
      links: %{
        "GitHub" => "https://github.com/scoutapp/scout_apm_elixir",
        "Docs" => "http://docs.scoutapm.com/elixir"
      }
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
