defmodule CareflexWeb.UserSocket do
  @moduledoc """
  WebSocket for GraphQL subscriptions.
  """

  use Phoenix.Socket
  use Absinthe.Phoenix.Socket, schema: CareflexWeb.Schema

  ## Channels
  # channel "room:*", CareflexWeb.RoomChannel

  @impl true
  def connect(_params, socket, _connect_info) do
    # In production, authenticate the socket connection here
    {:ok, socket}
  end

  @impl true
  def id(_socket), do: nil
end
