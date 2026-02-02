defmodule CareflexCore.Repo.Migrations.CreateAuditLogs do
  use Ecto.Migration

  def change do
    execute "CREATE TYPE user_role AS ENUM ('patient', 'agent', 'admin', 'system')",
            "DROP TYPE user_role"

    create table(:audit_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # Actor information
      add :user_id, :binary_id
      add :user_role, :user_role, null: false
      add :user_email, :string

      # Action details
      add :action, :string, null: false
      add :resource_type, :string, null: false
      add :resource_id, :binary_id

      # Change tracking (JSONB for flexibility)
      add :changes, :map, default: %{}
      add :metadata, :map, default: %{}

      # Request context
      add :ip_address, :string
      add :user_agent, :text

      # Timestamp (immutable)
      add :inserted_at, :utc_datetime, null: false
    end

    create index(:audit_logs, [:user_id])
    create index(:audit_logs, [:resource_type, :resource_id])
    create index(:audit_logs, [:action])
    create index(:audit_logs, [:inserted_at])

    # Composite index for user activity queries
    create index(:audit_logs, [:user_id, :inserted_at])
  end
end
