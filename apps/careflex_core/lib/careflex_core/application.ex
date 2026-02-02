defmodule CareflexCore.Application do
  @moduledoc """
  The CareflexCore Application service and supervision tree.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Repo
      CareflexCore.Repo,
      # Start Finch for HTTP requests
      {Finch, name: CareflexCore.Finch},
      # Start Oban for background jobs
      {Oban, Application.fetch_env!(:careflex_core, Oban)},
      # Start PubSub
      {Phoenix.PubSub, name: CareFlex.PubSub}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: CareflexCore.Supervisor)
  end
end
