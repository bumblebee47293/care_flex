defmodule CareflexCore.Repo.Migrations.CreateBenefits do
  use Ecto.Migration

  def change do
    execute "CREATE TYPE benefit_type AS ENUM ('transportation', 'meals', 'fitness', 'otc_items', 'utilities')",
            "DROP TYPE benefit_type"

    execute "CREATE TYPE benefit_status AS ENUM ('active', 'expired', 'depleted')",
            "DROP TYPE benefit_status"

    create table(:benefits, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :patient_id, references(:patients, type: :binary_id, on_delete: :restrict), null: false

      # Benefit details
      add :benefit_type, :benefit_type, null: false
      add :total_allocated, :decimal, precision: 10, scale: 2, null: false
      add :used_amount, :decimal, precision: 10, scale: 2, default: 0
      add :status, :benefit_status, default: "active", null: false

      # Period tracking
      add :period_start, :date, null: false
      add :period_end, :date, null: false

      # External integration
      add :external_plan_id, :string
      add :last_synced_at, :utc_datetime

      # Audit fields
      add :inserted_at, :utc_datetime, null: false
      add :updated_at, :utc_datetime, null: false
      add :deleted_at, :utc_datetime
    end

    create index(:benefits, [:patient_id])
    create index(:benefits, [:benefit_type])
    create index(:benefits, [:status])
    create index(:benefits, [:period_start, :period_end])
    create index(:benefits, [:deleted_at])

    # Composite index for eligibility checks
    create index(:benefits, [:patient_id, :benefit_type, :status])
  end
end
