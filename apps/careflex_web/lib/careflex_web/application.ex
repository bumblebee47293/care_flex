defmodule CareflexWeb.Application do
  @moduledoc """
  The CareflexWeb Application service and supervision tree.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      CareflexWeb.Telemetry,
      # Start the Endpoint (http/https)
      CareflexWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: CareflexWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CareflexWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
