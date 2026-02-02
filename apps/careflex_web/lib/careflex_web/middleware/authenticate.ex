defmodule CareflexWeb.Middleware.Authenticate do
  @moduledoc """
  Absinthe middleware to authenticate requests.
  """
  @behaviour Absinthe.Middleware

  alias CareflexCore.Guardian

  def call(resolution, _config) do
    case resolution.context do
      %{current_user: _user} ->
        resolution

      %{token: token} ->
        case Guardian.resource_from_token(token) do
          {:ok, user, _claims} ->
            Absinthe.Resolution.put_result(resolution, {:ok, user})
            |> Map.update!(:context, &Map.put(&1, :current_user, user))

          {:error, _reason} ->
            resolution
            |> Absinthe.Resolution.put_result({:error, "Invalid or expired token"})
        end

      _ ->
        resolution
        |> Absinthe.Resolution.put_result({:error, "Not authenticated"})
    end
  end
end
