import Config

# Runtime production configuration
config :careflex_core, CareflexCore.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  ssl: true

config :careflex_web, CareflexWeb.Endpoint,
  url: [host: System.get_env("PHX_HOST"), port: 443, scheme: "https"],
  http: [
    ip: {0, 0, 0, 0, 0, 0, 0, 0},
    port: String.to_integer(System.get_env("PORT") || "4000")
  ],
  secret_key_base: System.get_env("SECRET_KEY_BASE")

# Configure Guardian secret
config :careflex_web, CareflexWeb.Guardian,
  secret_key: System.get_env("GUARDIAN_SECRET_KEY")

# Configure Cloak encryption key
config :careflex_core, CareflexCore.Vault,
  ciphers: [
    default: {
      Cloak.Ciphers.AES.GCM,
      tag: "AES.GCM.V1",
      key: Base.decode64!(System.get_env("CLOAK_KEY"))
    }
  ]
