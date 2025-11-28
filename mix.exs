defmodule ScoutApm.Mixfile do
  use Mix.Project

  def project do
    [
      app: :scout_apm,
      version: "1.0.7",
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
    base_deps = [
      {:plug, "~> 1.0"},
      {:jason, "~> 1.0"},

      # We only use `request/5` from hackney, which hasn't changed in the 1.0 line.
      {:hackney, "~> 1.0"},
      {:approximate_histogram, "~> 0.1.1"},
      {:telemetry, "~> 1.0", optional: true},

      #########################
      # Dev & Testing Deps

      {:ex_doc, ">= 0.0.0", only: [:dev]},
      # {:credo, "~> 0.5", only: [:dev, :test]},  # Temporarily disabled - incompatible with Elixir 1.19
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},

      # Phoenix core - always included for dev/test
      {:phoenix, "~> 1.6", only: [:dev, :test]},
      {:phoenix_html, phoenix_html_version(), only: [:dev, :test]}
    ]

    # Conditionally add template engine dependencies based on MIX_TEMPLATE_ENGINES
    template_deps =
      if include_live_view?() do
        [{:phoenix_live_view, "~> 0.18", only: [:dev, :test]}]
      else
        [{:phoenix_slime, "~> 0.9.0", only: [:dev, :test]}]
      end

    base_deps ++ template_deps
  end

  defp description() do
    """
    ScoutAPM agent for Phoenix & Elixir projects. For more information, visit https://scoutapm.com/elixir.
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
        "Docs" => "http://docs.scoutapm.com/#elixir-agent"
      }
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Template engine testing configuration
  # Set MIX_TEMPLATE_ENGINES=legacy to test with phoenix_slime instead of phoenix_live_view
  defp template_engines_mode do
    System.get_env("MIX_TEMPLATE_ENGINES", "modern")
  end

  defp include_live_view? do
    template_engines_mode() != "legacy"
  end

  defp phoenix_html_version do
    if include_live_view?() do
      "~> 3.0"
    else
      "~> 2.14"
    end
  end
end
