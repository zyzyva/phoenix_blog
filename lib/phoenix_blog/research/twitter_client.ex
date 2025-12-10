defmodule PhoenixBlog.Research.TwitterClient do
  @moduledoc """
  Client for fetching tweets from X/Twitter API v2.

  Requires at minimum Basic tier ($200/month) for useful access.
  Free tier only allows 100 reads/month which is insufficient for research.

  Capabilities:
  - User timeline: Get up to 3,200 recent tweets from any user
  - Recent search: Search tweets from the last 7 days
  - Rate limits: 75 requests/hour for user timeline
  """

  require Logger

  @base_url "https://api.twitter.com/2"

  @doc """
  Gets recent tweets from a specific user by username.

  Options:
  - `:limit` - Number of tweets to fetch, max 100 (default: 10)
  - `:exclude` - List of tweet types to exclude: "retweets", "replies" (default: ["retweets"])
  """
  def get_user_tweets(username, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    exclude = Keyword.get(opts, :exclude, ["retweets"])

    with {:ok, user_id} <- get_user_id(username) do
      url = "#{@base_url}/users/#{user_id}/tweets"

      params = [
        max_results: min(limit, 100),
        exclude: Enum.join(exclude, ","),
        "tweet.fields": "created_at,public_metrics,entities",
        expansions: "author_id",
        "user.fields": "username,name"
      ]

      case Req.get(url, headers: auth_headers(), params: params) do
        {:ok, %{status: 200, body: body}} ->
          tweets = parse_tweets(body)
          {:ok, tweets}

        {:ok, %{status: 429}} ->
          {:error, "Rate limit exceeded. Try again later."}

        {:ok, %{status: status, body: body}} ->
          {:error, "Twitter API error #{status}: #{inspect(body)}"}

        {:error, reason} ->
          {:error, "Request failed: #{inspect(reason)}"}
      end
    end
  end

  @doc """
  Searches recent tweets (last 7 days) matching a query.

  Options:
  - `:limit` - Number of tweets to fetch, max 100 (default: 10)
  - `:sort_order` - "recency" or "relevancy" (default: "relevancy")
  """
  def search_recent(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    sort_order = Keyword.get(opts, :sort_order, "relevancy")

    url = "#{@base_url}/tweets/search/recent"

    params = [
      query: query,
      max_results: min(limit, 100),
      sort_order: sort_order,
      "tweet.fields": "created_at,public_metrics,entities",
      expansions: "author_id",
      "user.fields": "username,name"
    ]

    case Req.get(url, headers: auth_headers(), params: params) do
      {:ok, %{status: 200, body: body}} ->
        tweets = parse_tweets(body)
        {:ok, tweets}

      {:ok, %{status: 429}} ->
        {:error, "Rate limit exceeded. Try again later."}

      {:ok, %{status: status, body: body}} ->
        {:error, "Twitter API error #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Gets tweets from multiple marketing expert accounts.
  """
  def get_expert_tweets(opts \\ []) do
    limit_per_user = Keyword.get(opts, :limit, 5)
    experts = Keyword.get(opts, :experts, default_experts())

    results =
      experts
      |> Task.async_stream(fn username ->
        case get_user_tweets(username, limit: limit_per_user) do
          {:ok, tweets} -> tweets
          {:error, _} -> []
        end
      end, max_concurrency: 2, timeout: 30_000)
      |> Enum.flat_map(fn
        {:ok, tweets} -> tweets
        {:exit, _} -> []
      end)
      |> Enum.sort_by(& &1.metrics.like_count, :desc)

    {:ok, results}
  end

  @doc """
  Returns list of marketing experts to follow.
  """
  def default_experts do
    [
      "boringmarketer",  # Boring Marketing (practical tactics)
      "harrydry",        # Marketing Examples
      "alexgarciamkt",   # Content marketing
      "dickiebush",      # Content creation
      "theandreboso",    # B2B marketing
      "amandanat",       # Content strategy
      "lenaborodich"     # Growth
    ]
  end

  @doc """
  Checks if Twitter API is configured with sufficient access.
  """
  def configured? do
    bearer_token() != nil
  end

  # Private functions

  defp get_user_id(username) do
    url = "#{@base_url}/users/by/username/#{username}"

    case Req.get(url, headers: auth_headers()) do
      {:ok, %{status: 200, body: %{"data" => %{"id" => id}}}} ->
        {:ok, id}

      {:ok, %{status: 404}} ->
        {:error, "User not found: #{username}"}

      {:ok, %{status: status, body: body}} ->
        {:error, "Twitter API error #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  defp parse_tweets(%{"data" => tweets, "includes" => %{"users" => users}}) when is_list(tweets) do
    user_map = Map.new(users, fn u -> {u["id"], u} end)

    Enum.map(tweets, fn tweet ->
      user = Map.get(user_map, tweet["author_id"], %{})
      metrics = tweet["public_metrics"] || %{}

      %{
        id: tweet["id"],
        text: tweet["text"],
        author_id: tweet["author_id"],
        author_username: user["username"],
        author_name: user["name"],
        created_at: tweet["created_at"],
        url: "https://twitter.com/#{user["username"]}/status/#{tweet["id"]}",
        metrics: %{
          like_count: metrics["like_count"] || 0,
          retweet_count: metrics["retweet_count"] || 0,
          reply_count: metrics["reply_count"] || 0,
          quote_count: metrics["quote_count"] || 0,
          impression_count: metrics["impression_count"] || 0
        },
        entities: tweet["entities"]
      }
    end)
  end

  defp parse_tweets(%{"data" => tweets}) when is_list(tweets) do
    Enum.map(tweets, fn tweet ->
      metrics = tweet["public_metrics"] || %{}

      %{
        id: tweet["id"],
        text: tweet["text"],
        author_id: tweet["author_id"],
        created_at: tweet["created_at"],
        url: nil,
        metrics: %{
          like_count: metrics["like_count"] || 0,
          retweet_count: metrics["retweet_count"] || 0,
          reply_count: metrics["reply_count"] || 0
        }
      }
    end)
  end

  defp parse_tweets(_), do: []

  defp auth_headers do
    [{"authorization", "Bearer #{bearer_token()}"}]
  end

  defp bearer_token, do: Application.get_env(:phoenix_blog, :twitter_bearer_token)
end
