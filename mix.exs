defmodule VSMCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :vsm_core,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      
      # Package metadata
      description: "Core Viable System Model (VSM) implementation in Elixir",
      package: package(),
      docs: [
        main: "VSMCore",
        extras: ["README.md"]
      ],
      
      # Test configuration
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {VSMCore.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Core dependencies
      {:gen_stage, "~> 1.2"},
      {:telemetry, "~> 1.2"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      
      # VSM packages (when published)
      # {:vsm_starter, "~> 0.1"},
      # {:vsm_telemetry, "~> 0.1"},
      # {:vsm_rate_limiter, "~> 0.1"},
      # {:vsm_goldrush, "~> 0.1"},
      
      # Development and testing
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end
  
  defp package do
    [
      maintainers: ["VSM Core Team"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/viable-systems/vsm-core"
      }
    ]
  end
end
