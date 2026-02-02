defmodule CareFlex.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      releases: releases()
    ]
  end

  defp deps do
    []
  end

  defp aliases do
    [
      setup: ["cmd mix setup"],
      test: ["cmd mix test"]
    ]
  end

  defp releases do
    [
      care_flex: [
        applications: [
          careflex_core: :permanent,
          careflex_web: :permanent
        ]
      ]
    ]
  end
end
