defmodule CareflexCore.Guardian do
  @moduledoc """
  Guardian implementation for JWT token generation and verification.
  """
  use Guardian, otp_app: :careflex_core

  alias CareflexCore.Auth

  def subject_for_token(%{id: id}, _claims) do
    {:ok, to_string(id)}
  end

  def subject_for_token(_, _) do
    {:error, :invalid_subject}
  end

  def resource_from_claims(%{"sub" => id}) do
    case Auth.get_user!(String.to_integer(id)) do
      nil -> {:error, :resource_not_found}
      user -> {:ok, user}
    end
  rescue
    Ecto.NoResultsError -> {:error, :resource_not_found}
  end

  def resource_from_claims(_claims) do
    {:error, :invalid_claims}
  end

  @doc """
  Generate tokens for user.
  """
  def generate_tokens(user) do
    {:ok, access_token, access_claims} = encode_and_sign(user, %{}, token_type: "access", ttl: {1, :hour})
    {:ok, refresh_token, refresh_claims} = encode_and_sign(user, %{}, token_type: "refresh", ttl: {7, :day})

    {:ok, %{
      access_token: access_token,
      refresh_token: refresh_token,
      access_expires_at: access_claims["exp"],
      refresh_expires_at: refresh_claims["exp"]
    }}
  end

  @doc """
  Refresh access token using refresh token.
  """
  def refresh_tokens(refresh_token) do
    with {:ok, _old_stuff, {new_access_token, new_access_claims}} <-
           refresh(refresh_token, ttl: {1, :hour}) do
      {:ok, %{
        access_token: new_access_token,
        access_expires_at: new_access_claims["exp"]
      }}
    end
  end
end
