defmodule CareflexCore.Auth.User do
  @moduledoc """
  User schema for authentication and authorization.

  Supports three roles:
  - :patient - Can view own data
  - :agent - Can view and manage patient appointments
  - :admin - Full system access
  """
  use Ecto.Schema
  import Ecto.Changeset

  @roles [:patient, :agent, :admin]
  @statuses [:active, :inactive, :locked]

  schema "users" do
    field :email, CareflexCore.Encrypted.Binary
    field :email_hash, :string
    field :password_hash, :string
    field :password, :string, virtual: true
    field :role, Ecto.Enum, values: @roles, default: :patient
    field :first_name, CareflexCore.Encrypted.Binary
    field :last_name, CareflexCore.Encrypted.Binary
    field :phone, CareflexCore.Encrypted.Binary
    field :status, Ecto.Enum, values: @statuses, default: :active
    field :last_login_at, :utc_datetime
    field :failed_login_attempts, :integer, default: 0
    field :locked_at, :utc_datetime
    field :deleted_at, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :role, :first_name, :last_name, :phone, :status])
    |> validate_required([:email, :role])
    |> validate_format(:email, ~r/@/)
    |> validate_length(:password, min: 8, max: 100)
    |> validate_inclusion(:role, @roles)
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint(:email_hash)
    |> put_email_hash()
    |> put_password_hash()
  end

  @doc false
  def registration_changeset(user, attrs) do
    user
    |> changeset(attrs)
    |> validate_required([:password, :first_name, :last_name])
  end

  @doc false
  def login_changeset(user, attrs) do
    user
    |> cast(attrs, [:last_login_at, :failed_login_attempts, :locked_at])
  end

  defp put_email_hash(changeset) do
    case get_change(changeset, :email) do
      nil ->
        changeset
      email ->
        hash = :crypto.hash(:sha256, String.downcase(email)) |> Base.encode16(case: :lower)
        put_change(changeset, :email_hash, hash)
    end
  end

  defp put_password_hash(changeset) do
    case get_change(changeset, :password) do
      nil ->
        changeset
      password ->
        put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
    end
  end
end
