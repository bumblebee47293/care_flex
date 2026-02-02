defmodule CareflexWeb.Middleware.Authorize do
  @moduledoc """
  Absinthe middleware to authorize requests based on user role.
  """
  @behaviour Absinthe.Middleware

  alias CareflexCore.Auth

  def call(resolution, config) do
    action = Keyword.get(config, :action)

    case resolution.context do
      %{current_user: user} ->
        case Auth.authorize(user, action) do
          :ok ->
            resolution

          {:error, :unauthorized} ->
            resolution
            |> Absinthe.Resolution.put_result({:error, "Unauthorized: insufficient permissions"})
        end

      _ ->
        resolution
        |> Absinthe.Resolution.put_result({:error, "Not authenticated"})
    end
  end
end
