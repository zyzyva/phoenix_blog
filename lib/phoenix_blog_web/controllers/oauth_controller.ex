defmodule PhoenixBlogWeb.OAuthController do
  @moduledoc """
  Handles OAuth callbacks for social media platform authentication.
  """
  use PhoenixBlogWeb, :controller

  alias PhoenixBlog.Social
  alias PhoenixBlog.Social.OAuth
  alias PhoenixBlog.Social.Clients.TwitterClient

  require Logger

  @doc """
  Initiates OAuth flow for a platform.
  """
  def authorize(conn, %{"platform" => platform}) do
    user_id = get_session(conn, :user_id)

    if user_id do
      state = generate_state()
      # Store state and code_verifier in session for verification
      conn = put_session(conn, :oauth_state, state)

      case OAuth.authorization_url(platform, state) do
        {:ok, url, code_verifier} ->
          conn
          |> put_session(:oauth_code_verifier, code_verifier)
          |> redirect(external: url)

        {:error, reason} ->
          conn
          |> put_flash(:error, "Failed to start OAuth: #{reason}")
          |> redirect(to: ~p"/marketing/accounts")
      end
    else
      conn
      |> put_flash(:error, "You must be logged in to connect accounts")
      |> redirect(to: ~p"/")
    end
  end

  @doc """
  Handles OAuth callback from platforms.
  """
  def callback(conn, %{"platform" => "twitter"} = params) do
    handle_callback(conn, "twitter", params)
  end

  def callback(conn, %{"platform" => "linkedin"} = params) do
    handle_callback(conn, "linkedin", params)
  end

  def callback(conn, %{"platform" => "reddit"} = params) do
    handle_callback(conn, "reddit", params)
  end

  def callback(conn, %{"platform" => platform}) do
    conn
    |> put_flash(:error, "Unsupported platform: #{platform}")
    |> redirect(to: ~p"/marketing/accounts")
  end

  defp handle_callback(conn, platform, %{"code" => code, "state" => state}) do
    stored_state = get_session(conn, :oauth_state)
    user_id = get_session(conn, :user_id)

    cond do
      user_id == nil ->
        conn
        |> put_flash(:error, "Session expired. Please try again.")
        |> redirect(to: ~p"/")

      state != stored_state ->
        Logger.warning("OAuth state mismatch for #{platform}")

        conn
        |> put_flash(:error, "Invalid OAuth state. Please try again.")
        |> redirect(to: ~p"/marketing/accounts")

      true ->
        complete_oauth(conn, platform, code, user_id)
    end
  end

  defp handle_callback(conn, platform, %{"error" => error}) do
    Logger.warning("OAuth error for #{platform}: #{error}")

    conn
    |> put_flash(:error, "Authorization denied: #{error}")
    |> redirect(to: ~p"/marketing/accounts")
  end

  defp handle_callback(conn, _platform, _params) do
    conn
    |> put_flash(:error, "Invalid OAuth callback")
    |> redirect(to: ~p"/marketing/accounts")
  end

  defp complete_oauth(conn, platform, code, user_id) do
    code_verifier = get_session(conn, :oauth_code_verifier)

    opts =
      if code_verifier do
        [code_verifier: code_verifier]
      else
        []
      end

    with {:ok, tokens} <- OAuth.exchange_code(platform, code, opts),
         {:ok, user_info} <- get_platform_user_info(platform, tokens.access_token),
         {:ok, _account} <- save_account(user_id, platform, tokens, user_info) do
      conn
      |> clear_session_oauth_data()
      |> put_flash(:info, "Successfully connected #{platform_display_name(platform)}!")
      |> redirect(to: ~p"/marketing/accounts")
    else
      {:error, reason} ->
        Logger.error("Failed to complete OAuth for #{platform}: #{reason}")

        conn
        |> clear_session_oauth_data()
        |> put_flash(:error, "Failed to connect account: #{reason}")
        |> redirect(to: ~p"/marketing/accounts")
    end
  end

  defp get_platform_user_info("twitter", access_token) do
    TwitterClient.get_me(access_token)
  end

  defp get_platform_user_info("linkedin", access_token) do
    # LinkedIn userinfo endpoint
    case Req.get("https://api.linkedin.com/v2/userinfo",
           headers: [{"authorization", "Bearer #{access_token}"}]
         ) do
      {:ok, %{status: 200, body: body}} ->
        {:ok,
         %{
           id: body["sub"],
           name: body["name"],
           username: body["email"] || body["name"]
         }}

      {:ok, %{status: status, body: body}} ->
        {:error, "LinkedIn API error (#{status}): #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Failed to fetch LinkedIn profile: #{inspect(reason)}"}
    end
  end

  defp get_platform_user_info("reddit", access_token) do
    case Req.get("https://oauth.reddit.com/api/v1/me",
           headers: [
             {"authorization", "Bearer #{access_token}"},
             {"user-agent", "PhoenixBlog/1.0"}
           ]
         ) do
      {:ok, %{status: 200, body: body}} ->
        {:ok,
         %{
           id: body["id"],
           name: body["name"],
           username: body["name"]
         }}

      {:ok, %{status: status, body: body}} ->
        {:error, "Reddit API error (#{status}): #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Failed to fetch Reddit profile: #{inspect(reason)}"}
    end
  end

  defp get_platform_user_info(platform, _access_token) do
    {:error, "Unsupported platform: #{platform}"}
  end

  defp save_account(user_id, platform, tokens, user_info) do
    expires_at =
      if tokens.expires_in do
        DateTime.utc_now()
        |> DateTime.add(tokens.expires_in, :second)
        |> DateTime.truncate(:second)
      end

    Social.connect_account(user_id, %{
      platform: platform,
      platform_user_id: user_info.id,
      platform_username: user_info[:username] || user_info[:name],
      access_token: tokens.access_token,
      refresh_token: tokens.refresh_token,
      token_expires_at: expires_at,
      scopes: parse_scopes(tokens.scope),
      metadata: %{
        name: user_info[:name],
        profile_image_url: user_info[:profile_image_url]
      }
    })
  end

  defp parse_scopes(nil), do: []
  defp parse_scopes(scope) when is_binary(scope), do: String.split(scope, " ")
  defp parse_scopes(scopes) when is_list(scopes), do: scopes

  defp clear_session_oauth_data(conn) do
    conn
    |> delete_session(:oauth_state)
    |> delete_session(:oauth_code_verifier)
  end

  defp generate_state do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end

  defp platform_display_name("twitter"), do: "X/Twitter"
  defp platform_display_name("linkedin"), do: "LinkedIn"
  defp platform_display_name("reddit"), do: "Reddit"
  defp platform_display_name(platform), do: String.capitalize(platform)
end
