import Config

# Configure careflex_core
config :careflex_core,
  ecto_repos: [CareflexCore.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure database
config :careflex_core, CareflexCore.Repo,
  database: "careflex_dev",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Configure Oban
config :careflex_core, Oban,
  repo: CareflexCore.Repo,
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    {Oban.Plugins.Cron,
     crontab: [
       # Run no-show predictor daily at 2 AM
       {"0 2 * * *", CareflexCore.Workers.NoShowPredictor},
       # Sync benefits daily at 3 AM
       {"0 3 * * *", CareflexCore.Workers.BenefitsSyncWorker}
     ]}
  ],
  queues: [default: 10, notifications: 20, integrations: 5]

# Configure Cloak for PII encryption
config :careflex_core, CareflexCore.Vault,
  ciphers: [
    default: {
      Cloak.Ciphers.AES.GCM,
      tag: "AES.GCM.V1",
      key: Base.decode64!("your-32-byte-key-base64-encoded-here==")
    }
  ]

# Configure careflex_web
config :careflex_web,
  ecto_repos: [CareflexCore.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :careflex_web, CareflexWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: CareflexWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: CareFlex.PubSub,
  live_view: [signing_salt: "your-signing-salt-here"]

# Configure Guardian for JWT
config :careflex_core, CareflexCore.Guardian,
  issuer: "careflex",
  secret_key: "your-guardian-secret-key-here"

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :user_id, :patient_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config
import_config "#{config_env()}.exs"
