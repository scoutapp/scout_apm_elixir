defmodule ScoutApm.Mixfile do
  use Mix.Project

  def project do
    [app: :scout_apm,
     version: "0.2.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     description: description(),
     package: package(),
   ]

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
       :timex,
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
      {:poison, "~> 2.0"},
      {:hackney, "~> 1.6"},
      {:timex, "~> 3.0"},
      {:approximate_histogram, "~>0.1.0"},

      # Release Tools
      {:ex_doc, ">= 0.0.0", only: :dev},

      #########################
      # Dev & Testing Deps

      {:propcheck, "~> 0.0", only: [:dev, :test]},
      {:credo, "~> 0.5", only: [:dev, :test]},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},

      # TODO: Should this be in the dev-only dependencies? It is needed for dialyzer to complete correctly.
      {:phoenix, "~> 1.0", only: [:dev, :test]},
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
     files: ["lib", "mix.exs", "README*", "LICENSE*"],
     maintainers: ["Scout Team"],
     licenses: ["Scout Software Agent License"],
     links: %{"GitHub" => "https://github.com/scoutapp/scout_apm_elixir",
              "Docs" => "http://help.apm.scoutapp.com/#elixir-agent"}]
  end
end
