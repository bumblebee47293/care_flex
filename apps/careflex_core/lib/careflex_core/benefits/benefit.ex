defmodule CareflexCore.Benefits.Benefit do
  @moduledoc """
  Benefit schema for tracking patient benefits allocation and usage.

  Supports various benefit types with period-based tracking and
  external plan integration.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @benefit_types [:transportation, :meals, :fitness, :otc_items, :utilities]
  @statuses [:active, :expired, :depleted]

  schema "benefits" do
    belongs_to :patient, CareflexCore.Care.Patient

    # Benefit details
    field :benefit_type, Ecto.Enum, values: @benefit_types
    field :total_allocated, :decimal
    field :used_amount, :decimal, default: Decimal.new("0")
    field :status, Ecto.Enum, values: @statuses, default: :active

    # Period tracking
    field :period_start, :date
    field :period_end, :date

    # External integration
    field :external_plan_id, :string
    field :last_synced_at, :utc_datetime

    # Audit fields
    timestamps(type: :utc_datetime)
    field :deleted_at, :utc_datetime
  end

  @doc """
  Changeset for creating a new benefit.
  """
  def changeset(benefit, attrs) do
    benefit
    |> cast(attrs, [
      :patient_id,
      :benefit_type,
      :total_allocated,
      :period_start,
      :period_end,
      :external_plan_id
    ])
    |> validate_required([
      :patient_id,
      :benefit_type,
      :total_allocated,
      :period_start,
      :period_end
    ])
    |> validate_number(:total_allocated, greater_than: 0)
    |> validate_period_dates()
    |> foreign_key_constraint(:patient_id)
  end

  @doc """
  Changeset for recording benefit usage.
  """
  def usage_changeset(benefit, amount) do
    benefit
    |> change()
    |> put_change(:used_amount, Decimal.add(benefit.used_amount, Decimal.new(to_string(amount))))
    |> validate_number(:used_amount, less_than_or_equal_to: Decimal.to_float(benefit.total_allocated))
    |> maybe_update_status()
  end

  @doc """
  Changeset for syncing with external system.
  """
  def sync_changeset(benefit, attrs) do
    benefit
    |> cast(attrs, [:total_allocated, :used_amount, :status])
    |> put_change(:last_synced_at, DateTime.utc_now())
  end

  defp validate_period_dates(changeset) do
    period_start = get_field(changeset, :period_start)
    period_end = get_field(changeset, :period_end)

    if period_start && period_end && Date.compare(period_start, period_end) != :lt do
      add_error(changeset, :period_end, "must be after period start")
    else
      changeset
    end
  end

  defp maybe_update_status(changeset) do
    total = get_field(changeset, :total_allocated)
    used = get_change(changeset, :used_amount) || get_field(changeset, :used_amount)

    if Decimal.compare(used, total) == :eq do
      put_change(changeset, :status, :depleted)
    else
      changeset
    end
  end

  @doc """
  Returns remaining balance for a benefit.
  """
  def remaining_balance(%__MODULE__{} = benefit) do
    Decimal.sub(benefit.total_allocated, benefit.used_amount)
  end
end
