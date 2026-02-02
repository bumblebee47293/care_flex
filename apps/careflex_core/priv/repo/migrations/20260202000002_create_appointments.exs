defmodule CareflexCore.Repo.Migrations.CreateAppointments do
  use Ecto.Migration

  def change do
    # Create enums
    execute "CREATE TYPE care_service_type AS ENUM ('home_visit', 'telehealth', 'transportation', 'meal_delivery', 'wellness_check')",
            "DROP TYPE care_service_type"

    execute "CREATE TYPE appointment_status AS ENUM ('scheduled', 'confirmed', 'in_progress', 'completed', 'cancelled', 'no_show')",
            "DROP TYPE appointment_status"

    create table(:appointments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :patient_id, references(:patients, type: :binary_id, on_delete: :restrict), null: false

      # Appointment details
      add :care_service_type, :care_service_type, null: false
      add :scheduled_at, :utc_datetime, null: false
      add :duration_minutes, :integer, default: 60
      add :status, :appointment_status, default: "scheduled", null: false

      # External provider integration
      add :provider_id, :string
      add :provider_name, :string

      # Cancellation tracking
      add :cancellation_reason, :text
      add :cancelled_at, :utc_datetime
      add :cancelled_by_id, :binary_id

      # ML/Analytics
      add :no_show_risk_score, :integer, default: 0

      # Notes
      add :notes, :text

      # Audit fields
      add :inserted_at, :utc_datetime, null: false
      add :updated_at, :utc_datetime, null: false
      add :deleted_at, :utc_datetime
    end

    create index(:appointments, [:patient_id])
    create index(:appointments, [:scheduled_at])
    create index(:appointments, [:status])
    create index(:appointments, [:care_service_type])
    create index(:appointments, [:no_show_risk_score])
    create index(:appointments, [:deleted_at])

    # Composite index for common queries
    create index(:appointments, [:patient_id, :scheduled_at])
    create index(:appointments, [:status, :scheduled_at])
  end
end
