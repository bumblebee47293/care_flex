defmodule CareflexWeb.Context do
  @moduledoc """
  Plug for building GraphQL context.

  Extracts request information and prepares context for resolvers.
  In production, this would also handle authentication.
  """

  @behaviour Plug

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    context = build_context(conn)
    Absinthe.Plug.put_options(conn, context: context)
  end

  defp build_context(conn) do
    %{
      pubsub: CareFlex.PubSub,
      ip_address: get_ip_address(conn),
      user_agent: get_user_agent(conn)
      # In production, add:
      # current_user: get_current_user(conn),
      # current_role: get_current_role(conn)
    }
  end

  defp get_ip_address(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [ip | _] -> ip
      [] -> to_string(:inet_parse.ntoa(conn.remote_ip))
    end
  end

  defp get_user_agent(conn) do
    case get_req_header(conn, "user-agent") do
      [agent | _] -> agent
      [] -> "Unknown"
    end
  end
end
