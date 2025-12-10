defmodule PhoenixBlog.Social do
  @moduledoc """
  The Social context for managing social media accounts, posts, and analytics.
  """

  import Ecto.Query, warn: false
  alias PhoenixBlog.Repo
  alias PhoenixBlog.Social.{Account, AnalyticsRecord, Post, PostPlatform}

  # ============================================================================
  # Account Functions
  # ============================================================================

  @doc """
  Lists all connected accounts for a user.
  """
  def list_accounts(user_id) do
    Account
    |> where([a], a.user_id == ^user_id)
    |> where([a], a.status == "active")
    |> order_by([a], asc: a.platform)
    |> Repo.all()
  end

  @doc """
  Lists accounts by platform for a user.
  """
  def list_accounts_by_platform(user_id, platform) do
    Account
    |> where([a], a.user_id == ^user_id and a.platform == ^platform)
    |> where([a], a.status == "active")
    |> Repo.all()
  end

  @doc """
  Gets a single account.
  """
  def get_account!(id), do: Repo.get!(Account, id)

  @doc """
  Gets an account by platform and platform user ID.
  """
  def get_account_by_platform_id(platform, platform_user_id) do
    Account
    |> where([a], a.platform == ^platform and a.platform_user_id == ^platform_user_id)
    |> Repo.one()
  end

  @doc """
  Connects a new social account after OAuth.
  """
  def connect_account(user_id, attrs) do
    %Account{}
    |> Account.changeset(Map.put(attrs, :user_id, user_id))
    |> Repo.insert(
      on_conflict: {:replace, [:access_token, :refresh_token, :token_expires_at, :status]},
      conflict_target: [:platform, :platform_user_id]
    )
  end

  @doc """
  Updates account tokens after refresh.
  """
  def update_account_tokens(%Account{} = account, attrs) do
    account
    |> Account.token_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Marks an account as expired or revoked.
  """
  def revoke_account(%Account{} = account) do
    account
    |> Account.token_changeset(%{status: "revoked"})
    |> Repo.update()
  end

  @doc """
  Deletes a connected account.
  """
  def delete_account(%Account{} = account) do
    Repo.delete(account)
  end

  @doc """
  Returns accounts with tokens expiring soon.
  """
  def list_expiring_accounts(within_days \\ 7) do
    cutoff = DateTime.utc_now() |> DateTime.add(within_days, :day)

    Account
    |> where([a], a.status == "active")
    |> where([a], not is_nil(a.token_expires_at))
    |> where([a], a.token_expires_at < ^cutoff)
    |> Repo.all()
  end

  # ============================================================================
  # Social Post Functions
  # ============================================================================

  @doc """
  Lists all posts for a user with optional filters.
  """
  def list_posts(user_id, opts \\ []) do
    status = Keyword.get(opts, :status)
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)

    Post
    |> where([p], p.user_id == ^user_id)
    |> maybe_filter_by_status(status)
    |> order_by([p], desc: p.inserted_at)
    |> limit(^limit)
    |> offset(^offset)
    |> preload(:post_platforms)
    |> Repo.all()
  end

  @doc """
  Lists posts scheduled for publishing.
  """
  def list_scheduled_posts do
    now = DateTime.utc_now()

    Post
    |> where([p], p.status == "scheduled")
    |> where([p], p.scheduled_for <= ^now)
    |> preload(post_platforms: :social_account)
    |> Repo.all()
  end

  @doc """
  Lists upcoming scheduled posts for a user.
  """
  def list_upcoming_posts(user_id, limit \\ 10) do
    now = DateTime.utc_now()

    Post
    |> where([p], p.user_id == ^user_id)
    |> where([p], p.status == "scheduled")
    |> where([p], p.scheduled_for > ^now)
    |> order_by([p], asc: p.scheduled_for)
    |> limit(^limit)
    |> preload(:post_platforms)
    |> Repo.all()
  end

  @doc """
  Gets a single post with all associations.
  """
  def get_post!(id) do
    Post
    |> Repo.get!(id)
    |> Repo.preload(post_platforms: [:social_account, :analytics])
  end

  @doc """
  Creates a new social post.
  """
  def create_post(user_id, attrs) do
    %Post{}
    |> Post.changeset(Map.put(attrs, :user_id, user_id))
    |> Repo.insert()
  end

  @doc """
  Updates a social post.
  """
  def update_post(%Post{} = post, attrs) do
    post
    |> Post.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Schedules a post for future publishing.
  """
  def schedule_post(%Post{} = post, scheduled_for) do
    post
    |> Post.schedule_changeset(scheduled_for)
    |> Repo.update()
  end

  @doc """
  Adds target platforms to a post.
  """
  def add_post_platforms(%Post{} = post, account_ids) when is_list(account_ids) do
    Enum.map(account_ids, fn account_id ->
      %PostPlatform{}
      |> PostPlatform.changeset(%{
        social_post_id: post.id,
        social_account_id: account_id
      })
      |> Repo.insert()
    end)
  end

  @doc """
  Deletes a social post.
  """
  def delete_post(%Post{} = post) do
    Repo.delete(post)
  end

  @doc """
  Returns a changeset for tracking post changes.
  """
  def change_post(%Post{} = post, attrs \\ %{}) do
    Post.changeset(post, attrs)
  end

  # ============================================================================
  # Post Platform Functions
  # ============================================================================

  @doc """
  Gets a post platform record.
  """
  def get_post_platform!(id) do
    PostPlatform
    |> Repo.get!(id)
    |> Repo.preload([:social_account, :social_post])
  end

  @doc """
  Updates a post platform after publishing.
  """
  def update_post_platform(%PostPlatform{} = post_platform, attrs) do
    post_platform
    |> PostPlatform.publish_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Marks a post as publishing.
  """
  def mark_publishing(%PostPlatform{} = post_platform) do
    update_post_platform(post_platform, %{status: "publishing"})
  end

  @doc """
  Marks a post as successfully published.
  """
  def mark_published(%PostPlatform{} = post_platform, platform_post_id, platform_url) do
    update_post_platform(post_platform, %{
      status: "published",
      platform_post_id: platform_post_id,
      platform_url: platform_url,
      published_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  @doc """
  Marks a post as failed.
  """
  def mark_failed(%PostPlatform{} = post_platform, error_message) do
    update_post_platform(post_platform, %{
      status: "failed",
      error_message: error_message
    })
  end

  # ============================================================================
  # Analytics Functions
  # ============================================================================

  @doc """
  Records analytics for a post platform.
  """
  def record_analytics(%PostPlatform{} = post_platform, attrs) do
    %AnalyticsRecord{}
    |> AnalyticsRecord.changeset(
      Map.merge(attrs, %{
        social_post_platform_id: post_platform.id,
        fetched_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })
    )
    |> Repo.insert()
  end

  @doc """
  Gets the latest analytics for a post platform.
  """
  def get_latest_analytics(%PostPlatform{} = post_platform) do
    AnalyticsRecord
    |> where([a], a.social_post_platform_id == ^post_platform.id)
    |> order_by([a], desc: a.fetched_at)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Lists analytics history for a post platform.
  """
  def list_analytics_history(post_platform_id, limit \\ 30) do
    AnalyticsRecord
    |> where([a], a.social_post_platform_id == ^post_platform_id)
    |> order_by([a], desc: a.fetched_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Aggregates analytics for a user across all platforms.
  """
  def aggregate_analytics(user_id, opts \\ []) do
    days = Keyword.get(opts, :days, 30)
    since = DateTime.utc_now() |> DateTime.add(-days, :day)

    query =
      from a in AnalyticsRecord,
        join: pp in PostPlatform,
        on: a.social_post_platform_id == pp.id,
        join: p in Post,
        on: pp.social_post_id == p.id,
        where: p.user_id == ^user_id,
        where: a.fetched_at >= ^since,
        select: %{
          total_impressions: sum(a.impressions),
          total_engagements: sum(a.engagements),
          total_likes: sum(a.likes),
          total_comments: sum(a.comments),
          total_shares: sum(a.shares),
          total_clicks: sum(a.clicks)
        }

    Repo.one(query) ||
      %{
        total_impressions: 0,
        total_engagements: 0,
        total_likes: 0,
        total_comments: 0,
        total_shares: 0,
        total_clicks: 0
      }
  end

  # ============================================================================
  # Stats Functions
  # ============================================================================

  @doc """
  Returns counts of posts by status for a user.
  """
  def count_posts_by_status(user_id) do
    Post
    |> where([p], p.user_id == ^user_id)
    |> group_by([p], p.status)
    |> select([p], {p.status, count(p.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Returns counts of connected accounts by platform for a user.
  """
  def count_accounts_by_platform(user_id) do
    Account
    |> where([a], a.user_id == ^user_id)
    |> where([a], a.status == "active")
    |> group_by([a], a.platform)
    |> select([a], {a.platform, count(a.id)})
    |> Repo.all()
    |> Map.new()
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp maybe_filter_by_status(query, nil), do: query
  defp maybe_filter_by_status(query, status), do: where(query, [p], p.status == ^status)
end
