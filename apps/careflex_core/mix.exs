defmodule CareflexCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :careflex_core,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      mod: {CareflexCore.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Database
      {:ecto_sql, "~> 3.11"},
      {:postgrex, ">= 0.0.0"},

      # Background Jobs
      {:oban, "~> 2.17"},

      # PII Encryption
      {:cloak_ecto, "~> 1.2"},

      # HTTP Client
      {:finch, "~> 0.18"},
      {:jason, "~> 1.4"},

      # Utilities
      {:timex, "~> 3.7"},
      {:bcrypt_elixir, "~> 3.0"},

      # Authentication
      {:guardian, "~> 2.3"},
      {:comeonin, "~> 5.4"},

      # Testing
      {:ex_machina, "~> 2.7", only: :test},
      {:faker, "~> 0.18", only: :test},
      {:excoveralls, "~> 0.18", only: :test},
      {:mox, "~> 1.1", only: :test},
      {:stream_data, "~> 0.6", only: :test},

      # Code Quality
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
