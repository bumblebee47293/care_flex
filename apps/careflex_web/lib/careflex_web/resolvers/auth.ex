defmodule CareflexWeb.Resolvers.Auth do
  @moduledoc """
  GraphQL resolvers for authentication.
  """

  alias CareflexCore.Auth
  alias CareflexCore.Guardian

  @doc """
  Register a new user.
  """
  def register(_parent, %{input: input}, _resolution) do
    case Auth.register_user(input, %{action: "user_registration"}) do
      {:ok, user} ->
        {:ok, tokens} = Guardian.generate_tokens(user)

        {:ok, %{
          user: user,
          access_token: tokens.access_token,
          refresh_token: tokens.refresh_token
        }}

      {:error, changeset} ->
        {:error, message: "Registration failed", details: format_errors(changeset)}
    end
  end

  @doc """
  Login user.
  """
  def login(_parent, %{email: email, password: password}, _resolution) do
    case Auth.authenticate_user(email, password) do
      {:ok, user} ->
        {:ok, tokens} = Guardian.generate_tokens(user)

        {:ok, %{
          user: user,
          access_token: tokens.access_token,
          refresh_token: tokens.refresh_token
        }}

      {:error, :invalid_credentials} ->
        {:error, message: "Invalid email or password"}

      {:error, :account_locked} ->
        {:error, message: "Account is locked due to too many failed login attempts"}

      {:error, :account_inactive} ->
        {:error, message: "Account is inactive"}
    end
  end

  @doc """
  Refresh access token.
  """
  def refresh_token(_parent, %{refresh_token: refresh_token}, _resolution) do
    case Guardian.refresh_tokens(refresh_token) do
      {:ok, tokens} ->
        {:ok, %{
          access_token: tokens.access_token
        }}

      {:error, _reason} ->
        {:error, message: "Invalid or expired refresh token"}
    end
  end

  @doc """
  Get current user.
  """
  def me(_parent, _args, %{context: %{current_user: user}}) do
    {:ok, user}
  end

  def me(_parent, _args, _resolution) do
    {:error, message: "Not authenticated"}
  end

  @doc """
  Change password.
  """
  def change_password(_parent, %{current_password: current, new_password: new_pass}, %{context: %{current_user: user}}) do
    case Auth.change_password(user, current, new_pass, %{user_id: user.id}) do
      {:ok, updated_user} ->
        {:ok, updated_user}

      {:error, :invalid_password} ->
        {:error, message: "Current password is incorrect"}

      {:error, changeset} ->
        {:error, message: "Password change failed", details: format_errors(changeset)}
    end
  end

  def change_password(_parent, _args, _resolution) do
    {:error, message: "Not authenticated"}
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
