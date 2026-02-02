defmodule CareflexWeb.Schema.AgentTypes do
  @moduledoc """
  GraphQL types for agent presence tracking.
  """
  use Absinthe.Schema.Notation

  @desc "Call center agent presence information"
  object :agent_presence do
    field :agent_id, non_null(:string), description: "Unique agent identifier"
    field :name, non_null(:string), description: "Agent display name"
    field :status, non_null(:agent_status), description: "Current agent status"
    field :online_at, non_null(:datetime), description: "When agent came online"
    field :current_patient_id, :integer, description: "Patient currently being assisted"
    field :metadata, :json, description: "Additional agent metadata"
  end

  @desc "Agent status enum"
  enum :agent_status do
    value :available, description: "Agent is available for calls"
    value :busy, description: "Agent is currently on a call"
    value :away, description: "Agent is temporarily away"
    value :offline, description: "Agent is offline"
  end

  @desc "Input for tracking agent presence"
  input_object :track_agent_input do
    field :agent_id, non_null(:string)
    field :name, non_null(:string)
    field :status, non_null(:agent_status)
    field :current_patient_id, :integer
  end

  # Queries
  object :agent_queries do
    @desc "List all currently online agents"
    field :online_agents, list_of(:agent_presence) do
      resolve &CareflexWeb.Resolvers.Agent.list_online_agents/3
    end
  end

  # Mutations
  object :agent_mutations do
    @desc "Track agent presence"
    field :track_agent, :agent_presence do
      arg :input, non_null(:track_agent_input)
      resolve &CareflexWeb.Resolvers.Agent.track_agent/3
    end

    @desc "Update agent status"
    field :update_agent_status, :agent_presence do
      arg :agent_id, non_null(:string)
      arg :status, non_null(:agent_status)
      resolve &CareflexWeb.Resolvers.Agent.update_agent_status/3
    end
  end

  # Subscriptions
  object :agent_subscriptions do
    @desc "Subscribe to agent presence changes"
    field :agent_presence_changed, :agent_presence do
      config fn _args, _context ->
        {:ok, topic: "agents"}
      end

      trigger [:track_agent, :update_agent_status], topic: fn _ ->
        "agents"
      end
    end
  end
end
