defmodule PhoenixBlog.Social.OAuth do
  @moduledoc """
  OAuth flow handling for social media platforms.

  Centralizes OAuth 2.0 authorization URLs, token exchange, and refresh logic.
  """

  require Logger

  @doc """
  Generates the OAuth authorization URL for a platform.
  """
  def authorization_url(platform, state, opts \\ [])

  def authorization_url("twitter", state, opts) do
    client_id = get_config(:twitter_client_id)
    redirect_uri = Keyword.get(opts, :redirect_uri, get_config(:twitter_callback_url))
    scopes = Keyword.get(opts, :scopes, ["tweet.read", "tweet.write", "users.read", "offline.access"])

    code_verifier = generate_code_verifier()
    code_challenge = generate_code_challenge(code_verifier)

    params =
      URI.encode_query(%{
        response_type: "code",
        client_id: client_id,
        redirect_uri: redirect_uri,
        scope: Enum.join(scopes, " "),
        state: state,
        code_challenge: code_challenge,
        code_challenge_method: "S256"
      })

    url = "https://twitter.com/i/oauth2/authorize?#{params}"
    {:ok, url, code_verifier}
  end

  def authorization_url("linkedin", state, opts) do
    client_id = get_config(:linkedin_client_id)
    redirect_uri = Keyword.get(opts, :redirect_uri, get_config(:linkedin_callback_url))
    scopes = Keyword.get(opts, :scopes, ["openid", "profile", "w_member_social"])

    params =
      URI.encode_query(%{
        response_type: "code",
        client_id: client_id,
        redirect_uri: redirect_uri,
        scope: Enum.join(scopes, " "),
        state: state
      })

    {:ok, "https://www.linkedin.com/oauth/v2/authorization?#{params}", nil}
  end

  def authorization_url("reddit", state, opts) do
    client_id = get_config(:reddit_client_id)
    redirect_uri = Keyword.get(opts, :redirect_uri, get_config(:reddit_callback_url))
    scopes = Keyword.get(opts, :scopes, ["identity", "submit", "read"])

    params =
      URI.encode_query(%{
        response_type: "code",
        client_id: client_id,
        redirect_uri: redirect_uri,
        scope: Enum.join(scopes, " "),
        state: state,
        duration: "permanent"
      })

    {:ok, "https://www.reddit.com/api/v1/authorize?#{params}", nil}
  end

  def authorization_url(platform, _state, _opts) do
    {:error, "Unsupported platform: #{platform}"}
  end

  @doc """
  Exchanges an authorization code for access tokens.
  """
  def exchange_code(platform, code, opts \\ [])

  def exchange_code("twitter", code, opts) do
    client_id = get_config(:twitter_client_id)
    redirect_uri = Keyword.get(opts, :redirect_uri, get_config(:twitter_callback_url))
    code_verifier = Keyword.fetch!(opts, :code_verifier)

    body = %{
      grant_type: "authorization_code",
      code: code,
      redirect_uri: redirect_uri,
      client_id: client_id,
      code_verifier: code_verifier
    }

    "https://api.twitter.com/2/oauth2/token"
    |> Req.post(form: body, headers: [{"content-type", "application/x-www-form-urlencoded"}])
    |> handle_token_response()
  end

  def exchange_code("linkedin", code, opts) do
    client_id = get_config(:linkedin_client_id)
    client_secret = get_config(:linkedin_client_secret)
    redirect_uri = Keyword.get(opts, :redirect_uri, get_config(:linkedin_callback_url))

    body = %{
      grant_type: "authorization_code",
      code: code,
      redirect_uri: redirect_uri,
      client_id: client_id,
      client_secret: client_secret
    }

    "https://www.linkedin.com/oauth/v2/accessToken"
    |> Req.post(form: body, headers: [{"content-type", "application/x-www-form-urlencoded"}])
    |> handle_token_response()
  end

  def exchange_code("reddit", code, opts) do
    client_id = get_config(:reddit_client_id)
    client_secret = get_config(:reddit_client_secret)
    redirect_uri = Keyword.get(opts, :redirect_uri, get_config(:reddit_callback_url))

    auth = Base.encode64("#{client_id}:#{client_secret}")

    body = %{
      grant_type: "authorization_code",
      code: code,
      redirect_uri: redirect_uri
    }

    "https://www.reddit.com/api/v1/access_token"
    |> Req.post(
      form: body,
      headers: [
        {"authorization", "Basic #{auth}"},
        {"content-type", "application/x-www-form-urlencoded"},
        {"user-agent", user_agent()}
      ]
    )
    |> handle_token_response()
  end

  def exchange_code(platform, _code, _opts) do
    {:error, "Unsupported platform: #{platform}"}
  end

  @doc """
  Refreshes an access token using a refresh token.
  """
  def refresh_token(platform, refresh_token, opts \\ [])

  def refresh_token("twitter", refresh_token, _opts) do
    client_id = get_config(:twitter_client_id)

    body = %{
      grant_type: "refresh_token",
      refresh_token: refresh_token,
      client_id: client_id
    }

    "https://api.twitter.com/2/oauth2/token"
    |> Req.post(form: body, headers: [{"content-type", "application/x-www-form-urlencoded"}])
    |> handle_token_response()
  end

  def refresh_token("linkedin", _refresh_token, _opts) do
    {:error, "LinkedIn does not support refresh tokens for this grant type"}
  end

  def refresh_token("reddit", refresh_token, _opts) do
    client_id = get_config(:reddit_client_id)
    client_secret = get_config(:reddit_client_secret)
    auth = Base.encode64("#{client_id}:#{client_secret}")

    body = %{
      grant_type: "refresh_token",
      refresh_token: refresh_token
    }

    "https://www.reddit.com/api/v1/access_token"
    |> Req.post(
      form: body,
      headers: [
        {"authorization", "Basic #{auth}"},
        {"content-type", "application/x-www-form-urlencoded"},
        {"user-agent", user_agent()}
      ]
    )
    |> handle_token_response()
  end

  def refresh_token(platform, _refresh_token, _opts) do
    {:error, "Unsupported platform: #{platform}"}
  end

  # PKCE helpers for Twitter OAuth 2.0
  defp generate_code_verifier do
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64(padding: false)
  end

  defp generate_code_challenge(verifier) do
    :crypto.hash(:sha256, verifier)
    |> Base.url_encode64(padding: false)
  end

  defp handle_token_response({:ok, %{status: 200, body: body}}) do
    {:ok,
     %{
       access_token: body["access_token"],
       refresh_token: body["refresh_token"],
       expires_in: body["expires_in"],
       scope: body["scope"],
       token_type: body["token_type"]
     }}
  end

  defp handle_token_response({:ok, %{status: status, body: body}}) do
    error = body["error"] || body["error_description"] || "Unknown error"
    Logger.error("OAuth token exchange failed (#{status}): #{inspect(body)}")
    {:error, "Token exchange failed: #{error}"}
  end

  defp handle_token_response({:error, reason}) do
    Logger.error("OAuth request failed: #{inspect(reason)}")
    {:error, "Failed to connect to OAuth server"}
  end

  defp get_config(key) do
    Application.get_env(:phoenix_blog, key)
  end

  defp user_agent do
    "PhoenixBlog/1.0 (by /u/phoenix_blog_app)"
  end
end
