defmodule PhoenixBlogWeb.Plugs.GitHubWebhookPlug do
  @moduledoc """
  Plug that verifies GitHub webhook signatures.

  GitHub signs each webhook payload with HMAC-SHA256 using a shared secret.
  This plug verifies that signature to ensure requests genuinely came from GitHub.

  ## How it works

  1. GitHub computes: HMAC-SHA256(secret, request_body)
  2. Sends signature in X-Hub-Signature-256 header
  3. We compute the same HMAC and compare
  4. If match → request is authentic
  """

  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    secret = get_webhook_secret()

    if secret do
      verify_signature(conn, secret)
    else
      Logger.warning("GITHUB_WEBHOOK_SECRET not configured, skipping verification")
      conn
    end
  end

  defp verify_signature(conn, secret) do
    signature_header =
      get_req_header(conn, "x-hub-signature-256")
      |> List.first()

    case signature_header do
      nil ->
        Logger.warning("GitHub webhook missing signature header")
        reject(conn, "Missing signature")

      signature ->
        {:ok, body, conn} = read_body(conn)

        if valid_signature?(body, secret, signature) do
          # Put the body back so the controller can read it
          %{conn | body_params: decode_body(body, conn)}
        else
          Logger.warning("GitHub webhook signature mismatch")
          reject(conn, "Invalid signature")
        end
    end
  end

  defp valid_signature?(body, secret, signature_header) do
    expected =
      :crypto.mac(:hmac, :sha256, secret, body)
      |> Base.encode16(case: :lower)

    expected_full = "sha256=#{expected}"

    # Use constant-time comparison to prevent timing attacks
    Plug.Crypto.secure_compare(expected_full, signature_header)
  end

  defp decode_body(body, conn) do
    content_type =
      get_req_header(conn, "content-type")
      |> List.first()
      |> to_string()

    if String.contains?(content_type, "application/json") do
      case Jason.decode(body) do
        {:ok, decoded} -> decoded
        {:error, _} -> %{}
      end
    else
      %{}
    end
  end

  defp reject(conn, reason) do
    conn
    |> put_status(401)
    |> Phoenix.Controller.json(%{error: reason})
    |> halt()
  end

  defp get_webhook_secret do
    Application.get_env(:phoenix_blog, :github_webhook_secret)
  end
end
