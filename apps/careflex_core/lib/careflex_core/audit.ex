defmodule CareflexCore.Audit do
  @moduledoc """
  The Audit context - manages immutable audit logs for compliance.

  All sensitive operations are logged with:
  - User identification
  - Action performed
  - Resource affected
  - Changes made
  - Request context (IP, user agent)
  """

  import Ecto.Query, warn: false
  alias CareflexCore.Repo
  alias CareflexCore.Audit.AuditLog

  @doc """
  Logs an action to the audit trail.

  ## Required fields
    * `:user_role` - Role of the user performing the action
    * `:action` - Action being performed
    * `:resource_type` - Type of resource being acted upon

  ## Optional fields
    * `:user_id` - ID of the user
    * `:user_email` - Email of the user
    * `:resource_id` - ID of the specific resource
    * `:changes` - Map of changes made
    * `:metadata` - Additional context
    * `:ip_address` - IP address of the request
    * `:user_agent` - User agent string
  """
  def log_action(attrs) do
    %AuditLog{}
    |> AuditLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Retrieves audit logs for a specific user.
  """
  def get_user_audit_logs(user_id, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 50)

    AuditLog
    |> where([a], a.user_id == ^user_id)
    |> order_by([a], desc: a.inserted_at)
    |> limit(^page_size)
    |> offset(^((page - 1) * page_size))
    |> Repo.all()
  end

  @doc """
  Retrieves audit logs for a specific resource.
  """
  def get_resource_audit_logs(resource_type, resource_id, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 50)

    AuditLog
    |> where([a], a.resource_type == ^resource_type)
    |> where([a], a.resource_id == ^resource_id)
    |> order_by([a], desc: a.inserted_at)
    |> limit(^page_size)
    |> offset(^((page - 1) * page_size))
    |> Repo.all()
  end

  @doc """
  Retrieves audit logs by action type.
  """
  def get_logs_by_action(action, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 50)
    from_date = Keyword.get(opts, :from_date)
    to_date = Keyword.get(opts, :to_date)

    query =
      AuditLog
      |> where([a], a.action == ^action)

    query =
      if from_date do
        where(query, [a], a.inserted_at >= ^from_date)
      else
        query
      end

    query =
      if to_date do
        where(query, [a], a.inserted_at <= ^to_date)
      else
        query
      end

    query
    |> order_by([a], desc: a.inserted_at)
    |> limit(^page_size)
    |> offset(^((page - 1) * page_size))
    |> Repo.all()
  end

  @doc """
  Generates an audit report for a date range.

  Returns aggregated statistics about actions performed.
  """
  def generate_audit_report(from_date, to_date) do
    AuditLog
    |> where([a], a.inserted_at >= ^from_date)
    |> where([a], a.inserted_at <= ^to_date)
    |> group_by([a], [a.action, a.user_role])
    |> select([a], %{
      action: a.action,
      user_role: a.user_role,
      count: count(a.id)
    })
    |> Repo.all()
  end
end
