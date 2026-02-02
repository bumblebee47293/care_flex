defmodule CareflexCore.DataLoader do
  @moduledoc """
  Dataloader source for efficient batch loading of associations.

  Prevents N+1 queries in GraphQL by batching database requests.
  """

  def data do
    Dataloader.Ecto.new(CareflexCore.Repo, query: &query/2)
  end

  def query(queryable, _params) do
    queryable
  end
end
