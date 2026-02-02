defmodule CareflexCore.Repo do
  use Ecto.Repo,
    otp_app: :careflex_core,
    adapter: Ecto.Adapters.Postgres
end
