defmodule CareflexCore.Repo.Migrations.CreatePatients do
  use Ecto.Migration

  def change do
    # Create enum for patient status
    execute "CREATE TYPE patient_status AS ENUM ('active', 'inactive', 'suspended')",
            "DROP TYPE patient_status"

    create table(:patients, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :external_id, :string, null: false

      # Encrypted PII fields
      add :first_name_encrypted, :binary
      add :last_name_encrypted, :binary
      add :email_encrypted, :binary
      add :email_hash, :binary, null: false
      add :phone_encrypted, :binary
      add :date_of_birth_encrypted, :binary

      # Non-sensitive fields
      add :timezone, :string, default: "America/New_York"
      add :status, :patient_status, default: "active", null: false

      # JSONB fields for flexible data
      add :communication_preferences, :map, default: %{}
      add :accessibility_needs, :map, default: %{}

      # Audit fields
      add :inserted_at, :utc_datetime, null: false
      add :updated_at, :utc_datetime, null: false
      add :deleted_at, :utc_datetime
    end

    create unique_index(:patients, [:external_id])
    create unique_index(:patients, [:email_hash])
    create index(:patients, [:status])
    create index(:patients, [:deleted_at])
  end
end
