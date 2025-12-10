defmodule PhoenixBlog.Social.Clients.TwitterClient do
  @moduledoc """
  X/Twitter API v2 client for posting and fetching analytics.

  Uses OAuth 2.0 user context for posting on behalf of users.

  ## Rate Limits (Free Tier)
  - 500 posts per month
  - 50 requests per 24 hours per user

  ## Configuration
  Set environment variables:
  - TWITTER_CLIENT_ID
  - TWITTER_CLIENT_SECRET
  - TWITTER_CALLBACK_URL
  """

  require Logger

  @api_base "https://api.twitter.com/2"
  @timeout 30_000
  @max_tweet_length 280

  @doc """
  Checks if Twitter API is configured.
  """
  def configured? do
    get_config(:twitter_client_id) != nil
  end

  @doc """
  Posts a tweet using the user's access token.

  ## Options
  - `:reply_to` - Tweet ID to reply to
  - `:media_ids` - List of media IDs to attach

  ## Returns
  - `{:ok, %{id: tweet_id, text: text}}` on success
  - `{:error, reason}` on failure
  """
  def post(access_token, text, opts \\ []) do
    if String.length(text) > @max_tweet_length do
      {:error, "Tweet exceeds #{@max_tweet_length} characters"}
    else
      do_post(access_token, text, opts)
    end
  end

  defp do_post(access_token, text, opts) do
    body = build_tweet_body(text, opts)

    "#{@api_base}/tweets"
    |> Req.post(
      json: body,
      headers: auth_headers(access_token),
      receive_timeout: @timeout
    )
    |> handle_post_response()
  end

  defp build_tweet_body(text, opts) do
    body = %{text: text}

    body =
      case Keyword.get(opts, :reply_to) do
        nil -> body
        tweet_id -> Map.put(body, :reply, %{in_reply_to_tweet_id: tweet_id})
      end

    case Keyword.get(opts, :media_ids) do
      nil -> body
      [] -> body
      media_ids -> Map.put(body, :media, %{media_ids: media_ids})
    end
  end

  @doc """
  Gets the authenticated user's profile.
  """
  def get_me(access_token) do
    "#{@api_base}/users/me"
    |> Req.get(
      headers: auth_headers(access_token),
      params: [{"user.fields", "id,name,username,profile_image_url"}],
      receive_timeout: @timeout
    )
    |> handle_user_response()
  end

  @doc """
  Gets metrics for a specific tweet.
  """
  def get_tweet_metrics(access_token, tweet_id) do
    "#{@api_base}/tweets/#{tweet_id}"
    |> Req.get(
      headers: auth_headers(access_token),
      params: [{"tweet.fields", "public_metrics,non_public_metrics,organic_metrics"}],
      receive_timeout: @timeout
    )
    |> handle_metrics_response()
  end

  @doc """
  Deletes a tweet.
  """
  def delete_tweet(access_token, tweet_id) do
    "#{@api_base}/tweets/#{tweet_id}"
    |> Req.delete(
      headers: auth_headers(access_token),
      receive_timeout: @timeout
    )
    |> handle_delete_response()
  end

  # Response handlers

  defp handle_post_response({:ok, %{status: 201, body: body}}) do
    data = body["data"]

    {:ok,
     %{
       id: data["id"],
       text: data["text"],
       url: "https://twitter.com/i/web/status/#{data["id"]}"
     }}
  end

  defp handle_post_response({:ok, %{status: 403, body: body}}) do
    error = get_error_detail(body)
    Logger.error("Twitter API: Forbidden - #{error}")
    {:error, "Cannot post: #{error}"}
  end

  defp handle_post_response({:ok, %{status: 429, headers: headers}}) do
    reset = get_rate_limit_reset(headers)
    Logger.warning("Twitter API: Rate limited. Resets at #{reset}")
    {:error, "Rate limited - try again after #{reset}"}
  end

  defp handle_post_response(response), do: handle_generic_response(response, "post")

  defp handle_user_response({:ok, %{status: 200, body: body}}) do
    data = body["data"]

    {:ok,
     %{
       id: data["id"],
       name: data["name"],
       username: data["username"],
       profile_image_url: data["profile_image_url"]
     }}
  end

  defp handle_user_response(response), do: handle_generic_response(response, "get user")

  defp handle_metrics_response({:ok, %{status: 200, body: body}}) do
    data = body["data"]
    public = data["public_metrics"] || %{}
    organic = data["organic_metrics"] || %{}

    {:ok,
     %{
       impressions: organic["impression_count"] || public["impression_count"],
       likes: public["like_count"],
       retweets: public["retweet_count"],
       replies: public["reply_count"],
       quotes: public["quote_count"],
       bookmarks: public["bookmark_count"],
       clicks: organic["url_link_clicks"],
       profile_clicks: organic["user_profile_clicks"],
       raw: data
     }}
  end

  defp handle_metrics_response(response), do: handle_generic_response(response, "get metrics")

  defp handle_delete_response({:ok, %{status: 200, body: %{"data" => %{"deleted" => true}}}}),
    do: :ok

  defp handle_delete_response(response), do: handle_generic_response(response, "delete")

  defp handle_generic_response({:ok, %{status: 401}}, action) do
    Logger.error("Twitter API: Unauthorized for #{action}")
    {:error, "Authentication failed - token may be expired"}
  end

  defp handle_generic_response({:ok, %{status: 429}}, action) do
    Logger.warning("Twitter API: Rate limited for #{action}")
    {:error, "Rate limited - try again later"}
  end

  defp handle_generic_response({:ok, %{status: status, body: body}}, action)
       when status >= 400 do
    error = get_error_detail(body)
    Logger.error("Twitter API: Error #{status} for #{action} - #{error}")
    {:error, "API error: #{error}"}
  end

  defp handle_generic_response({:error, %Req.TransportError{reason: :timeout}}, action) do
    Logger.error("Twitter API: Timeout for #{action}")
    {:error, "Request timed out"}
  end

  defp handle_generic_response({:error, reason}, action) do
    Logger.error("Twitter API: Request failed for #{action} - #{inspect(reason)}")
    {:error, "Failed to connect to Twitter API"}
  end

  # Helpers

  defp auth_headers(access_token) do
    [
      {"authorization", "Bearer #{access_token}"},
      {"content-type", "application/json"}
    ]
  end

  defp get_error_detail(body) do
    cond do
      is_map(body) && body["detail"] -> body["detail"]
      is_map(body) && body["errors"] -> hd(body["errors"])["message"]
      is_map(body) && body["title"] -> body["title"]
      true -> "Unknown error"
    end
  end

  defp get_rate_limit_reset(headers) do
    case List.keyfind(headers, "x-rate-limit-reset", 0) do
      {_, timestamp} ->
        timestamp
        |> String.to_integer()
        |> DateTime.from_unix!()
        |> Calendar.strftime("%H:%M:%S UTC")

      nil ->
        "unknown time"
    end
  end

  defp get_config(key) do
    Application.get_env(:phoenix_blog, key)
  end
end
