defmodule CareflexCore.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    execute "CREATE TYPE notification_type AS ENUM ('sms', 'voice', 'email')",
            "DROP TYPE notification_type"

    execute "CREATE TYPE notification_status AS ENUM ('pending', 'sent', 'delivered', 'failed')",
            "DROP TYPE notification_status"

    create table(:notifications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :patient_id, references(:patients, type: :binary_id, on_delete: :restrict), null: false
      add :appointment_id, references(:appointments, type: :binary_id, on_delete: :nilify_all)

      # Notification details
      add :notification_type, :notification_type, null: false
      add :status, :notification_status, default: "pending", null: false
      add :template_name, :string, null: false
      add :content, :text, null: false

      # Delivery tracking
      add :sent_at, :utc_datetime
      add :delivered_at, :utc_datetime
      add :failed_at, :utc_datetime
      add :failure_reason, :text

      # External provider tracking
      add :external_id, :string
      add :provider_response, :map

      # Audit fields
      add :inserted_at, :utc_datetime, null: false
      add :updated_at, :utc_datetime, null: false
    end

    create index(:notifications, [:patient_id])
    create index(:notifications, [:appointment_id])
    create index(:notifications, [:status])
    create index(:notifications, [:notification_type])
    create index(:notifications, [:inserted_at])
  end
end
