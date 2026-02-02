defmodule CareflexWeb.Resolvers.Agent do
  @moduledoc """
  GraphQL resolvers for agent presence tracking.
  """

  alias CareflexWeb.Presence

  @doc """
  List all currently online agents.
  """
  def list_online_agents(_parent, _args, _resolution) do
    presences = Presence.list("agents")

    agents =
      presences
      |> Enum.map(fn {agent_id, %{metas: metas}} ->
        # Get the most recent presence entry
        meta = List.first(metas)

        %{
          agent_id: agent_id,
          name: meta.name,
          status: String.to_existing_atom(meta.status),
          online_at: meta.online_at,
          current_patient_id: meta[:current_patient_id],
          metadata: meta[:metadata] || %{}
        }
      end)

    {:ok, agents}
  end

  @doc """
  Track agent presence (mutation).
  """
  def track_agent(_parent, %{input: input}, _resolution) do
    %{agent_id: agent_id, name: name, status: status} = input

    # Track presence
    {:ok, _} = Presence.track(
      self(),
      "agents",
      agent_id,
      %{
        name: name,
        status: Atom.to_string(status),
        online_at: DateTime.utc_now(),
        current_patient_id: input[:current_patient_id],
        metadata: %{}
      }
    )

    {:ok, %{
      agent_id: agent_id,
      name: name,
      status: status,
      online_at: DateTime.utc_now(),
      current_patient_id: input[:current_patient_id],
      metadata: %{}
    }}
  end

  @doc """
  Update agent status.
  """
  def update_agent_status(_parent, %{agent_id: agent_id, status: status}, _resolution) do
    # Get current presence
    case Presence.get_by_key("agents", agent_id) do
      [] ->
        {:error, "Agent not found"}

      %{metas: metas} ->
        meta = List.first(metas)

        # Update presence
        {:ok, _} = Presence.update(
          self(),
          "agents",
          agent_id,
          %{meta | status: Atom.to_string(status)}
        )

        {:ok, %{
          agent_id: agent_id,
          name: meta.name,
          status: status,
          online_at: meta.online_at,
          current_patient_id: meta[:current_patient_id],
          metadata: meta[:metadata] || %{}
        }}
    end
  end
end
