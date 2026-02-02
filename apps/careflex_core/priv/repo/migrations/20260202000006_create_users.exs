defmodule CareflexCore.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false
      add :email_hash, :string, null: false
      add :password_hash, :string, null: false
      add :role, :string, null: false, default: "patient"
      add :first_name, :binary
      add :last_name, :binary
      add :phone, :binary
      add :status, :string, null: false, default: "active"
      add :last_login_at, :utc_datetime
      add :failed_login_attempts, :integer, default: 0
      add :locked_at, :utc_datetime
      add :deleted_at, :utc_datetime

      timestamps()
    end

    create unique_index(:users, [:email_hash])
    create index(:users, [:role])
    create index(:users, [:status])
    create index(:users, [:deleted_at])
  end
end
