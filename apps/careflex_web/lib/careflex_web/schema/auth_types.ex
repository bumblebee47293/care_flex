defmodule CareflexWeb.Schema.AuthTypes do
  @moduledoc """
  GraphQL types for authentication.
  """
  use Absinthe.Schema.Notation

  @desc "User account"
  object :user do
    field :id, non_null(:id)
    field :email, non_null(:string)
    field :role, non_null(:user_role)
    field :first_name, :string
    field :last_name, :string
    field :phone, :string
    field :status, non_null(:user_status)
    field :last_login_at, :datetime
    field :inserted_at, non_null(:datetime)
  end

  @desc "User role enum"
  enum :user_role do
    value :patient, description: "Patient user"
    value :agent, description: "Call center agent"
    value :admin, description: "System administrator"
  end

  @desc "User status enum"
  enum :user_status do
    value :active, description: "Active account"
    value :inactive, description: "Inactive account"
    value :locked, description: "Locked account"
  end

  @desc "Authentication response"
  object :auth_response do
    field :user, non_null(:user)
    field :access_token, non_null(:string)
    field :refresh_token, non_null(:string)
  end

  @desc "Token refresh response"
  object :token_refresh_response do
    field :access_token, non_null(:string)
  end

  @desc "User registration input"
  input_object :register_input do
    field :email, non_null(:string)
    field :password, non_null(:string)
    field :first_name, non_null(:string)
    field :last_name, non_null(:string)
    field :phone, :string
    field :role, :user_role, default_value: :patient
  end

  # Queries
  object :auth_queries do
    @desc "Get current authenticated user"
    field :me, :user do
      resolve &CareflexWeb.Resolvers.Auth.me/3
    end
  end

  # Mutations
  object :auth_mutations do
    @desc "Register a new user"
    field :register, :auth_response do
      arg :input, non_null(:register_input)
      resolve &CareflexWeb.Resolvers.Auth.register/3
    end

    @desc "Login user"
    field :login, :auth_response do
      arg :email, non_null(:string)
      arg :password, non_null(:string)
      resolve &CareflexWeb.Resolvers.Auth.login/3
    end

    @desc "Refresh access token"
    field :refresh_token, :token_refresh_response do
      arg :refresh_token, non_null(:string)
      resolve &CareflexWeb.Resolvers.Auth.refresh_token/3
    end

    @desc "Change password"
    field :change_password, :user do
      arg :current_password, non_null(:string)
      arg :new_password, non_null(:string)
      resolve &CareflexWeb.Resolvers.Auth.change_password/3
    end
  end
end
