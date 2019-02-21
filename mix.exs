defmodule ScoutApm.Mixfile do
  use Mix.Project

  def project do
    [app: :scout_apm,
     version: "0.4.10",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     description: description(),
     package: package(),
   ]

  end

  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications:
     [
       :logger,
       :hackney,
       :plug,
       :poison
     ],
     mod: {ScoutApm.Application, []}]
  end

  defp deps do
    [
      {:plug, "~>1.0"},

      # We only use `encode!(map) and decode(map)`, which have existed since the start of poison,
      # so don't restrict the version of poison here. In the unlikely case that
      # either function is removed in a new version, we'll have to revisit.
      {:poison, ">= 0.0.0"},

      # We only use `request/5` from hackney, which hasn't changed in the 1.0 line.
      {:hackney, "~> 1.0"},

      {:approximate_histogram, "~>0.1.1"},
      {:telemetry, "~> 0.3.0", optional: true},

      #########################
      # Dev & Testing Deps

      {:ex_doc, ">= 0.0.0", only: [:dev]},
      {:credo, "~> 0.5", only: [:dev, :test]},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},

      # TODO: Should this be in the dev-only dependencies? It is needed for dialyzer to complete correctly.
      {:phoenix, "~> 1.0", only: [:dev, :test]},
      {:phoenix_slime, "~> 0.9.0", only: [:dev, :test]},
    ]
  end

  defp description() do
    """
    ScoutAPM agent for Phoenix & Elixir projects. For more information, visit https://apm.scoutapp.com/elixir.
    """
  end

  defp package do
    [# These are the default files included in the package
     name: :scout_apm,
     files: ["lib", "priv", "mix.exs", "README*", "LICENSE*"],
     maintainers: ["Scout Team"],
     licenses: ["Scout Software Agent License"],
     links: %{"GitHub" => "https://github.com/scoutapp/scout_apm_elixir",
              "Docs" => "http://help.apm.scoutapp.com/#elixir-agent"}]
  end
end
