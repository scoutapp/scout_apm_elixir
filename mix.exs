defmodule ScoutApm.Mixfile do
  use Mix.Project

  def project do
    [app: :scout_apm,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications:
     [
       :logger,
       :hackney,
     ],
     mod: {ScoutApm.Application, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:plug, "~>1.0"},
      {:poison, "~> 2.0"},
      {:hackney, "~> 1.7"},

      #########################
      # Dev & Testing Deps

      {:propcheck, "~> 0.0", only: [:dev, :test]},
      {:credo, "~> 0.5", only: [:dev, :test]},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},

      # TODO: Should this be in the dev-only dependencies? It is needed for dialyzer to complete correctly.
      {:phoenix, "~> 1.0", only: [:dev, :test]},
    ]
  end
end
