defmodule CareflexCore.Scheduling.Appointment do
  @moduledoc """
  Appointment schema for managing patient care schedules.

  Supports multiple care service types with timezone-aware scheduling,
  cancellation tracking, and no-show risk prediction.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @service_types [:home_visit, :telehealth, :transportation, :meal_delivery, :wellness_check]
  @statuses [:scheduled, :confirmed, :in_progress, :completed, :cancelled, :no_show]

  schema "appointments" do
    belongs_to :patient, CareflexCore.Care.Patient

    # Appointment details
    field :care_service_type, Ecto.Enum, values: @service_types
    field :scheduled_at, :utc_datetime
    field :duration_minutes, :integer, default: 60
    field :status, Ecto.Enum, values: @statuses, default: :scheduled

    # External provider integration
    field :provider_id, :string
    field :provider_name, :string

    # Cancellation tracking
    field :cancellation_reason, :string
    field :cancelled_at, :utc_datetime
    field :cancelled_by_id, :binary_id

    # ML/Analytics
    field :no_show_risk_score, :integer, default: 0

    # Notes
    field :notes, :string

    # Audit fields
    timestamps(type: :utc_datetime)
    field :deleted_at, :utc_datetime

    # Associations
    has_many :notifications, CareflexCore.Notifications.Notification
  end

  @doc """
  Changeset for scheduling a new appointment.
  """
  def changeset(appointment, attrs) do
    appointment
    |> cast(attrs, [
      :patient_id,
      :care_service_type,
      :scheduled_at,
      :duration_minutes,
      :provider_id,
      :provider_name,
      :notes
    ])
    |> validate_required([
      :patient_id,
      :care_service_type,
      :scheduled_at
    ])
    |> validate_number(:duration_minutes, greater_than: 0, less_than_or_equal_to: 480)
    |> validate_future_date()
    |> foreign_key_constraint(:patient_id)
  end

  @doc """
  Changeset for rescheduling an appointment.
  """
  def reschedule_changeset(appointment, attrs) do
    appointment
    |> cast(attrs, [:scheduled_at, :notes])
    |> validate_required([:scheduled_at])
    |> validate_future_date()
    |> put_change(:status, :scheduled)
  end

  @doc """
  Changeset for cancelling an appointment.
  """
  def cancel_changeset(appointment, attrs) do
    appointment
    |> cast(attrs, [:cancellation_reason, :cancelled_by_id])
    |> validate_required([:cancellation_reason])
    |> put_change(:status, :cancelled)
    |> put_change(:cancelled_at, DateTime.utc_now())
  end

  @doc """
  Changeset for updating appointment status.
  """
  def status_changeset(appointment, status) when status in @statuses do
    change(appointment, status: status)
  end

  @doc """
  Changeset for updating no-show risk score.
  """
  def risk_score_changeset(appointment, score) do
    appointment
    |> change(no_show_risk_score: score)
    |> validate_number(:no_show_risk_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
  end

  defp validate_future_date(changeset) do
    case get_change(changeset, :scheduled_at) do
      nil ->
        changeset

      scheduled_at ->
        if DateTime.compare(scheduled_at, DateTime.utc_now()) == :gt do
          changeset
        else
          add_error(changeset, :scheduled_at, "must be in the future")
        end
    end
  end
end
