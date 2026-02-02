defmodule CareflexWeb.Router do
  use CareflexWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug CareflexWeb.Context
  end

  scope "/" do
    pipe_through :api

    forward "/api/graphql", Absinthe.Plug,
      schema: CareflexWeb.Schema

    forward "/graphiql", Absinthe.Plug.GraphiQL,
      schema: CareflexWeb.Schema,
      socket: CareflexWeb.UserSocket,
      interface: :playground
  end
end
