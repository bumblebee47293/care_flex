defmodule CareflexCore.Audit.AuditLog do
  @moduledoc """
  Immutable audit log schema for tracking all sensitive operations.

  Records who did what, when, and what changed for compliance and security.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @user_roles [:patient, :agent, :admin, :system]

  schema "audit_logs" do
    # Actor information
    field :user_id, :binary_id
    field :user_role, Ecto.Enum, values: @user_roles
    field :user_email, :string

    # Action details
    field :action, :string
    field :resource_type, :string
    field :resource_id, :binary_id

    # Change tracking
    field :changes, :map, default: %{}
    field :metadata, :map, default: %{}

    # Request context
    field :ip_address, :string
    field :user_agent, :string

    # Timestamp (immutable - only inserted_at)
    field :inserted_at, :utc_datetime
  end

  @doc """
  Changeset for creating an audit log entry.

  Note: Audit logs are immutable and cannot be updated or deleted.
  """
  def changeset(audit_log, attrs) do
    audit_log
    |> cast(attrs, [
      :user_id,
      :user_role,
      :user_email,
      :action,
      :resource_type,
      :resource_id,
      :changes,
      :metadata,
      :ip_address,
      :user_agent
    ])
    |> validate_required([
      :user_role,
      :action,
      :resource_type
    ])
    |> put_change(:inserted_at, DateTime.utc_now())
  end
end
