defmodule CareflexCore.Care.Patient do
  @moduledoc """
  Patient schema with encrypted PII fields.

  All sensitive patient information is encrypted at rest using Cloak.
  Email addresses are both encrypted and hashed to allow lookups while
  maintaining security.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type_values [:active, :inactive, :suspended]

  schema "patients" do
    field :external_id, :string

    # Encrypted PII fields
    field :first_name, CareflexCore.Encrypted.Binary
    field :last_name, CareflexCore.Encrypted.Binary
    field :email, CareflexCore.Encrypted.Binary
    field :email_hash, :binary
    field :phone, CareflexCore.Encrypted.Binary
    field :date_of_birth, CareflexCore.Encrypted.Binary

    # Non-sensitive fields
    field :timezone, :string, default: "America/New_York"
    field :status, Ecto.Enum, values: @type_values, default: :active

    # JSONB fields
    field :communication_preferences, :map, default: %{}
    field :accessibility_needs, :map, default: %{}

    # Audit fields
    timestamps(type: :utc_datetime)
    field :deleted_at, :utc_datetime

    # Associations
    has_many :appointments, CareflexCore.Scheduling.Appointment
    has_many :benefits, CareflexCore.Benefits.Benefit
    has_many :notifications, CareflexCore.Notifications.Notification
  end

  @doc """
  Changeset for creating a new patient.
  """
  def changeset(patient, attrs) do
    patient
    |> cast(attrs, [
      :external_id,
      :first_name,
      :last_name,
      :email,
      :phone,
      :date_of_birth,
      :timezone,
      :status,
      :communication_preferences,
      :accessibility_needs
    ])
    |> validate_required([
      :external_id,
      :first_name,
      :last_name,
      :email,
      :timezone
    ])
    |> validate_format(:email, ~r/@/)
    |> validate_inclusion(:timezone, Tzdata.zone_list())
    |> unique_constraint(:external_id)
    |> unique_constraint(:email_hash)
    |> put_email_hash()
    |> generate_external_id()
  end

  @doc """
  Changeset for updating patient information.
  """
  def update_changeset(patient, attrs) do
    patient
    |> cast(attrs, [
      :first_name,
      :last_name,
      :phone,
      :timezone,
      :status,
      :communication_preferences,
      :accessibility_needs
    ])
    |> validate_inclusion(:timezone, Tzdata.zone_list())
  end

  defp put_email_hash(changeset) do
    case get_change(changeset, :email) do
      nil -> changeset
      email -> put_change(changeset, :email_hash, :crypto.hash(:sha256, email))
    end
  end

  defp generate_external_id(changeset) do
    if get_field(changeset, :external_id) do
      changeset
    else
      put_change(changeset, :external_id, Ecto.UUID.generate())
    end
  end
end
