defmodule PhoenixBlog.Research do
  @moduledoc """
  Context for marketing research - discovering, saving, and testing tactics.
  """

  import Ecto.Query, warn: false
  alias PhoenixBlog.Repo
  alias PhoenixBlog.Research.{RedditClient, TwitterClient, Tactic}

  # ============================================================================
  # Tactic CRUD
  # ============================================================================

  @doc """
  Lists all tactics with optional filters.
  """
  def list_tactics(opts \\ []) do
    status = Keyword.get(opts, :status)
    category = Keyword.get(opts, :category)
    limit = Keyword.get(opts, :limit, 50)

    Tactic
    |> maybe_filter_status(status)
    |> maybe_filter_category(category)
    |> order_by([t], desc: t.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Gets a single tactic.
  """
  def get_tactic!(id), do: Repo.get!(Tactic, id)

  @doc """
  Creates a tactic from manual entry.
  """
  def create_tactic(attrs) do
    %Tactic{}
    |> Tactic.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a tactic from a Reddit post.
  """
  def create_tactic_from_reddit(post, attrs \\ %{}) do
    base_attrs = %{
      title: post.title,
      description: post.selftext,
      source_url: post.permalink,
      source_platform: "reddit",
      source_author: post.author,
      source_score: post.score,
      source_comments: post.num_comments
    }

    create_tactic(Map.merge(base_attrs, attrs))
  end

  @doc """
  Updates a tactic.
  """
  def update_tactic(%Tactic{} = tactic, attrs) do
    tactic
    |> Tactic.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Starts testing a tactic.
  """
  def start_testing(%Tactic{} = tactic, test_plan) do
    tactic
    |> Tactic.start_test_changeset(test_plan)
    |> Repo.update()
  end

  @doc """
  Completes a tactic test.
  """
  def complete_test(%Tactic{} = tactic, status, results, metrics \\ %{}) do
    tactic
    |> Tactic.complete_test_changeset(%{
      status: status,
      test_results: results,
      metrics: metrics
    })
    |> Repo.update()
  end

  @doc """
  Archives a tactic.
  """
  def archive_tactic(%Tactic{} = tactic) do
    update_tactic(tactic, %{status: "archived"})
  end

  @doc """
  Deletes a tactic.
  """
  def delete_tactic(%Tactic{} = tactic) do
    Repo.delete(tactic)
  end

  # ============================================================================
  # Reddit Research
  # ============================================================================

  @doc """
  Fetches top marketing posts from Reddit.

  Returns posts from multiple subreddits, sorted by score.
  """
  def fetch_reddit_insights(opts \\ []) do
    if RedditClient.configured?() do
      RedditClient.get_marketing_insights(opts)
    else
      {:error, "Reddit API not configured. Set REDDIT_CLIENT_ID and REDDIT_CLIENT_SECRET."}
    end
  end

  @doc """
  Fetches top posts from a specific subreddit.
  """
  def fetch_subreddit_top(subreddit, opts \\ []) do
    if RedditClient.configured?() do
      RedditClient.get_top_posts(subreddit, opts)
    else
      {:error, "Reddit API not configured."}
    end
  end

  @doc """
  Searches Reddit for posts matching a query.
  """
  def search_reddit(query, opts \\ []) do
    if RedditClient.configured?() do
      RedditClient.search(query, opts)
    else
      {:error, "Reddit API not configured."}
    end
  end

  @doc """
  Returns the list of monitored subreddits.
  """
  def monitored_subreddits do
    RedditClient.default_subreddits()
  end

  # ============================================================================
  # Twitter/X Research (requires $200/month Basic tier)
  # ============================================================================

  @doc """
  Checks if Twitter API is configured.
  """
  def twitter_configured? do
    TwitterClient.configured?()
  end

  @doc """
  Fetches recent tweets from marketing experts.
  """
  def fetch_expert_tweets(opts \\ []) do
    if TwitterClient.configured?() do
      TwitterClient.get_expert_tweets(opts)
    else
      {:error, "Twitter API not configured. Set TWITTER_BEARER_TOKEN (requires $200/month Basic tier)."}
    end
  end

  @doc """
  Fetches tweets from a specific user.
  """
  def fetch_user_tweets(username, opts \\ []) do
    if TwitterClient.configured?() do
      TwitterClient.get_user_tweets(username, opts)
    else
      {:error, "Twitter API not configured."}
    end
  end

  @doc """
  Searches recent tweets (last 7 days).
  """
  def search_twitter(query, opts \\ []) do
    if TwitterClient.configured?() do
      TwitterClient.search_recent(query, opts)
    else
      {:error, "Twitter API not configured."}
    end
  end

  @doc """
  Returns the list of tracked marketing experts on Twitter.
  """
  def twitter_experts do
    TwitterClient.default_experts()
  end

  @doc """
  Creates a tactic from a tweet.
  """
  def create_tactic_from_tweet(tweet, attrs \\ %{}) do
    base_attrs = %{
      title: String.slice(tweet.text, 0, 100),
      description: tweet.text,
      source_url: tweet.url,
      source_platform: "twitter",
      source_author: tweet.author_username,
      source_score: tweet.metrics.like_count
    }

    create_tactic(Map.merge(base_attrs, attrs))
  end

  # ============================================================================
  # Stats
  # ============================================================================

  @doc """
  Returns counts of tactics by status.
  """
  def count_by_status do
    Tactic
    |> group_by([t], t.status)
    |> select([t], {t.status, count(t.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Returns validated tactics for reference.
  """
  def validated_tactics(opts \\ []) do
    category = Keyword.get(opts, :category)
    limit = Keyword.get(opts, :limit, 20)

    Tactic
    |> where([t], t.status == "validated")
    |> maybe_filter_category(category)
    |> order_by([t], desc: t.test_completed_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Returns debunked tactics to avoid.
  """
  def debunked_tactics(opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    Tactic
    |> where([t], t.status == "debunked")
    |> order_by([t], desc: t.test_completed_at)
    |> limit(^limit)
    |> Repo.all()
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp maybe_filter_status(query, nil), do: query
  defp maybe_filter_status(query, status), do: where(query, [t], t.status == ^status)

  defp maybe_filter_category(query, nil), do: query
  defp maybe_filter_category(query, category), do: where(query, [t], t.category == ^category)
end
