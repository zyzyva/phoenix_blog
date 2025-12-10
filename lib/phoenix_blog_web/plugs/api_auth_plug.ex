defmodule PhoenixBlogWeb.Plugs.ApiAuthPlug do
  @moduledoc """
  Plug that verifies API key authentication via Bearer token.

  Expects header: Authorization: Bearer <api_key>
  """

  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    api_key = get_api_key()

    if api_key do
      verify_bearer_token(conn, api_key)
    else
      Logger.warning("MARKETING_API_KEY not configured")
      reject(conn, "API not configured")
    end
  end

  defp verify_bearer_token(conn, expected_key) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> provided_key] ->
        if Plug.Crypto.secure_compare(provided_key, expected_key) do
          conn
        else
          Logger.warning("Invalid API key provided")
          reject(conn, "Invalid API key")
        end

      _ ->
        reject(conn, "Missing or invalid Authorization header")
    end
  end

  defp reject(conn, reason) do
    conn
    |> put_status(401)
    |> Phoenix.Controller.json(%{error: reason})
    |> halt()
  end

  defp get_api_key do
    Application.get_env(:phoenix_blog, :marketing_api_key)
  end
end
