# Dialyzer configuration
[
  plt_add_apps: [:mix, :ex_unit],
  plt_core_path: "priv/plts",
  plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
  plt_local_path: "priv/plts",

  # Warnings to enable
  warnings: [
    :error_handling,
    :underspecs,
    :unmatched_returns
  ],

  # Paths to analyze
  paths: [
    "_build/#{Mix.env()}/lib/careflex_core/ebin",
    "_build/#{Mix.env()}/lib/careflex_web/ebin"
  ],

  # Ignore warnings from dependencies
  ignore_warnings: ".dialyzer_ignore.exs"
]
