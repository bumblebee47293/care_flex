defmodule CareflexWeb.Presence do
  @moduledoc """
  Provides presence tracking for call center agents.

  Tracks which agents are currently online, their status (available/busy/away),
  and metadata like current patient they're assisting.
  """
  use Phoenix.Presence,
    otp_app: :careflex_web,
    pubsub_server: CareflexCore.PubSub
end
