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
       :plug,
       :poison
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

      # We only use `encode!(map)`, which has exited since the start of poison,
      # so don't restrict the version of poison here. In the unlikely case that
      # the encode! function is removed in a new version, we'll have to revisit.
      {:poison, ">= 0.0.0"},

      # We only use `request/5` from hackney, which hasn't changed in the 1.0 line.
      {:hackney, "~> 1.0"},

      {:approximate_histogram, "~>0.1.1"},

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
