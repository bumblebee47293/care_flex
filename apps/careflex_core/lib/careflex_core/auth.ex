defmodule CareflexCore.Auth do
  @moduledoc """
  Authentication and authorization context.

  Handles user registration, login, password management, and role-based access control.
  """

  import Ecto.Query, warn: false
  alias CareflexCore.Repo
  alias CareflexCore.Auth.User
  alias CareflexCore.Audit

  @doc """
  Register a new user.
  """
  def register_user(attrs, audit_context \\ %{}) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, user} ->
        Audit.log_action("user_registered", "User", user.id, %{role: user.role}, audit_context)
        {:ok, user}
      error ->
        error
    end
  end

  @doc """
  Authenticate user with email and password.
  """
  def authenticate_user(email, password) do
    email_hash = :crypto.hash(:sha256, String.downcase(email)) |> Base.encode16(case: :lower)

    user =
      User
      |> where([u], u.email_hash == ^email_hash)
      |> where([u], is_nil(u.deleted_at))
      |> Repo.one()

    cond do
      is_nil(user) ->
        # Prevent timing attacks
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}

      user.status == :locked ->
        {:error, :account_locked}

      user.status == :inactive ->
        {:error, :account_inactive}

      Bcrypt.verify_pass(password, user.password_hash) ->
        # Reset failed attempts and update last login
        {:ok, updated_user} =
          user
          |> User.login_changeset(%{
            last_login_at: DateTime.utc_now(),
            failed_login_attempts: 0
          })
          |> Repo.update()

        {:ok, updated_user}

      true ->
        # Increment failed attempts
        failed_attempts = user.failed_login_attempts + 1
        locked_at = if failed_attempts >= 5, do: DateTime.utc_now(), else: nil

        user
        |> User.login_changeset(%{
          failed_login_attempts: failed_attempts,
          locked_at: locked_at
        })
        |> Repo.update()

        {:error, :invalid_credentials}
    end
  end

  @doc """
  Get user by ID.
  """
  def get_user!(id) do
    User
    |> where([u], is_nil(u.deleted_at))
    |> Repo.get!(id)
  end

  @doc """
  Get user by email.
  """
  def get_user_by_email(email) do
    email_hash = :crypto.hash(:sha256, String.downcase(email)) |> Base.encode16(case: :lower)

    User
    |> where([u], u.email_hash == ^email_hash)
    |> where([u], is_nil(u.deleted_at))
    |> Repo.one()
  end

  @doc """
  List all users (admin only).
  """
  def list_users(opts \\ []) do
    User
    |> where([u], is_nil(u.deleted_at))
    |> apply_filters(opts)
    |> Repo.all()
  end

  defp apply_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:role, role}, query ->
        where(query, [u], u.role == ^role)
      {:status, status}, query ->
        where(query, [u], u.status == ^status)
      _, query ->
        query
    end)
  end

  @doc """
  Update user.
  """
  def update_user(user, attrs, audit_context \\ %{}) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated_user} ->
        Audit.log_action("user_updated", "User", user.id, attrs, audit_context)
        {:ok, updated_user}
      error ->
        error
    end
  end

  @doc """
  Change user password.
  """
  def change_password(user, current_password, new_password, audit_context \\ %{}) do
    if Bcrypt.verify_pass(current_password, user.password_hash) do
      user
      |> User.changeset(%{password: new_password})
      |> Repo.update()
      |> case do
        {:ok, updated_user} ->
          Audit.log_action("password_changed", "User", user.id, %{}, audit_context)
          {:ok, updated_user}
        error ->
          error
      end
    else
      {:error, :invalid_password}
    end
  end

  @doc """
  Unlock user account (admin only).
  """
  def unlock_account(user, audit_context \\ %{}) do
    user
    |> User.login_changeset(%{
      locked_at: nil,
      failed_login_attempts: 0
    })
    |> Repo.update()
    |> case do
      {:ok, updated_user} ->
        Audit.log_action("account_unlocked", "User", user.id, %{}, audit_context)
        {:ok, updated_user}
      error ->
        error
    end
  end

  @doc """
  Check if user has permission for action.
  """
  def authorize(user, action, resource \\ nil)

  # Admin has all permissions
  def authorize(%User{role: :admin}, _action, _resource), do: :ok

  # Agent permissions
  def authorize(%User{role: :agent}, action, _resource)
    when action in [:view_patients, :manage_appointments, :view_benefits] do
    :ok
  end

  # Patient permissions
  def authorize(%User{role: :patient, id: user_id}, :view_own_data, %{patient_id: patient_id})
    when user_id == patient_id do
    :ok
  end

  def authorize(%User{role: :patient}, :view_own_appointments, _resource), do: :ok
  def authorize(%User{role: :patient}, :view_own_benefits, _resource), do: :ok

  # Default deny
  def authorize(_user, _action, _resource), do: {:error, :unauthorized}
end
