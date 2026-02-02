defmodule CareflexCore.Notifications.Notification do
  @moduledoc """
  Notification schema for tracking patient communications.

  Supports SMS, voice, and email notifications with delivery tracking.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @notification_types [:sms, :voice, :email]
  @statuses [:pending, :sent, :delivered, :failed]

  schema "notifications" do
    belongs_to :patient, CareflexCore.Care.Patient
    belongs_to :appointment, CareflexCore.Scheduling.Appointment

    # Notification details
    field :notification_type, Ecto.Enum, values: @notification_types
    field :status, Ecto.Enum, values: @statuses, default: :pending
    field :template_name, :string
    field :content, :string

    # Delivery tracking
    field :sent_at, :utc_datetime
    field :delivered_at, :utc_datetime
    field :failed_at, :utc_datetime
    field :failure_reason, :string

    # External provider tracking
    field :external_id, :string
    field :provider_response, :map

    # Audit fields
    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a new notification.
  """
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [
      :patient_id,
      :appointment_id,
      :notification_type,
      :template_name,
      :content
    ])
    |> validate_required([
      :patient_id,
      :notification_type,
      :template_name,
      :content
    ])
    |> foreign_key_constraint(:patient_id)
    |> foreign_key_constraint(:appointment_id)
  end

  @doc """
  Changeset for marking notification as sent.
  """
  def sent_changeset(notification, external_id) do
    notification
    |> change(status: :sent, external_id: external_id)
    |> put_change(:sent_at, DateTime.utc_now())
  end

  @doc """
  Changeset for marking notification as delivered.
  """
  def delivered_changeset(notification) do
    notification
    |> change(status: :delivered)
    |> put_change(:delivered_at, DateTime.utc_now())
  end

  @doc """
  Changeset for marking notification as failed.
  """
  def failed_changeset(notification, reason) do
    notification
    |> change(status: :failed, failure_reason: reason)
    |> put_change(:failed_at, DateTime.utc_now())
  end
end
