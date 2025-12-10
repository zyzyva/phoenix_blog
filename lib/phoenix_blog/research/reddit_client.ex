defmodule PhoenixBlog.Research.RedditClient do
  @moduledoc """
  Client for fetching posts from Reddit's API.

  Reddit API is free with OAuth, allowing 1000 requests per 10 minutes.
  No paid tier required for read-only access.
  """

  require Logger

  @base_url "https://oauth.reddit.com"
  @auth_url "https://www.reddit.com/api/v1/access_token"
  @user_agent "PhoenixBlog Marketing Research/1.0"

  @doc """
  Fetches top posts from a subreddit.

  Options:
  - `:time` - "hour", "day", "week", "month", "year", "all" (default: "week")
  - `:limit` - Number of posts to fetch, max 100 (default: 25)
  """
  def get_top_posts(subreddit, opts \\ []) do
    time = Keyword.get(opts, :time, "week")
    limit = Keyword.get(opts, :limit, 25)

    with {:ok, token} <- get_access_token() do
      url = "#{@base_url}/r/#{subreddit}/top"

      case Req.get(url,
             headers: auth_headers(token),
             params: [t: time, limit: limit]
           ) do
        {:ok, %{status: 200, body: body}} ->
          posts = parse_posts(body)
          {:ok, posts}

        {:ok, %{status: status, body: body}} ->
          {:error, "Reddit API error #{status}: #{inspect(body)}"}

        {:error, reason} ->
          {:error, "Request failed: #{inspect(reason)}"}
      end
    end
  end

  @doc """
  Fetches hot posts from a subreddit.
  """
  def get_hot_posts(subreddit, opts \\ []) do
    limit = Keyword.get(opts, :limit, 25)

    with {:ok, token} <- get_access_token() do
      url = "#{@base_url}/r/#{subreddit}/hot"

      case Req.get(url,
             headers: auth_headers(token),
             params: [limit: limit]
           ) do
        {:ok, %{status: 200, body: body}} ->
          posts = parse_posts(body)
          {:ok, posts}

        {:ok, %{status: status, body: body}} ->
          {:error, "Reddit API error #{status}: #{inspect(body)}"}

        {:error, reason} ->
          {:error, "Request failed: #{inspect(reason)}"}
      end
    end
  end

  @doc """
  Searches for posts across Reddit or within a subreddit.
  """
  def search(query, opts \\ []) do
    subreddit = Keyword.get(opts, :subreddit)
    sort = Keyword.get(opts, :sort, "relevance")
    time = Keyword.get(opts, :time, "week")
    limit = Keyword.get(opts, :limit, 25)

    with {:ok, token} <- get_access_token() do
      url = if subreddit do
        "#{@base_url}/r/#{subreddit}/search"
      else
        "#{@base_url}/search"
      end

      params = [
        q: query,
        sort: sort,
        t: time,
        limit: limit,
        restrict_sr: if(subreddit, do: true, else: false)
      ]

      case Req.get(url, headers: auth_headers(token), params: params) do
        {:ok, %{status: 200, body: body}} ->
          posts = parse_posts(body)
          {:ok, posts}

        {:ok, %{status: status, body: body}} ->
          {:error, "Reddit API error #{status}: #{inspect(body)}"}

        {:error, reason} ->
          {:error, "Request failed: #{inspect(reason)}"}
      end
    end
  end

  @doc """
  Fetches top posts from multiple marketing-related subreddits.
  """
  def get_marketing_insights(opts \\ []) do
    subreddits = Keyword.get(opts, :subreddits, default_subreddits())
    time = Keyword.get(opts, :time, "week")
    limit_per_sub = Keyword.get(opts, :limit, 10)

    results =
      subreddits
      |> Task.async_stream(fn sub ->
        case get_top_posts(sub, time: time, limit: limit_per_sub) do
          {:ok, posts} ->
            Enum.map(posts, &Map.put(&1, :subreddit, sub))
          {:error, _} ->
            []
        end
      end, max_concurrency: 3, timeout: 30_000)
      |> Enum.flat_map(fn
        {:ok, posts} -> posts
        {:exit, _} -> []
      end)
      |> Enum.sort_by(& &1.score, :desc)

    {:ok, results}
  end

  @doc """
  Returns list of default marketing-related subreddits to monitor.
  """
  def default_subreddits do
    [
      "marketing",
      "entrepreneur",
      "startups",
      "SaaS",
      "growthacking",
      "digital_marketing",
      "SEO",
      "socialmedia",
      "content_marketing",
      "indiehackers"
    ]
  end

  @doc """
  Checks if Reddit API credentials are configured.
  """
  def configured? do
    client_id() != nil and client_secret() != nil
  end

  # Private functions

  defp get_access_token do
    # Reddit uses client credentials flow for read-only access
    auth = Base.encode64("#{client_id()}:#{client_secret()}")

    case Req.post(@auth_url,
           headers: [
             {"authorization", "Basic #{auth}"},
             {"user-agent", @user_agent},
             {"content-type", "application/x-www-form-urlencoded"}
           ],
           body: "grant_type=client_credentials"
         ) do
      {:ok, %{status: 200, body: %{"access_token" => token}}} ->
        {:ok, token}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Reddit auth failed: #{status} - #{inspect(body)}")
        {:error, "Authentication failed"}

      {:error, reason} ->
        Logger.error("Reddit auth request failed: #{inspect(reason)}")
        {:error, "Authentication request failed"}
    end
  end

  defp auth_headers(token) do
    [
      {"authorization", "Bearer #{token}"},
      {"user-agent", @user_agent}
    ]
  end

  defp parse_posts(%{"data" => %{"children" => children}}) do
    Enum.map(children, fn %{"data" => post} ->
      %{
        id: post["id"],
        title: post["title"],
        selftext: post["selftext"],
        url: post["url"],
        permalink: "https://reddit.com#{post["permalink"]}",
        score: post["score"],
        upvote_ratio: post["upvote_ratio"],
        num_comments: post["num_comments"],
        author: post["author"],
        created_utc: post["created_utc"],
        is_self: post["is_self"],
        link_flair_text: post["link_flair_text"]
      }
    end)
  end

  defp parse_posts(_), do: []

  defp client_id, do: Application.get_env(:phoenix_blog, :reddit_client_id)
  defp client_secret, do: Application.get_env(:phoenix_blog, :reddit_client_secret)
end
