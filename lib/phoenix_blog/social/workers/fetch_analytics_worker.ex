defmodule PhoenixBlog.Social.Workers.FetchAnalyticsWorker do
  @moduledoc """
  Worker that fetches analytics for a specific post from a platform.
  """
  use Oban.Worker, queue: :analytics, max_attempts: 3

  alias PhoenixBlog.Social
  alias PhoenixBlog.Social.Clients.TwitterClient

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"post_platform_id" => post_platform_id}}) do
    post_platform = Social.get_post_platform!(post_platform_id)
    account = post_platform.social_account

    case fetch_analytics(account, post_platform) do
      {:ok, metrics} ->
        Social.record_analytics(post_platform, metrics)
        :ok

      {:error, reason} ->
        Logger.warning("Failed to fetch analytics for #{post_platform_id}: #{reason}")
        # Don't fail the job for analytics fetch errors
        :ok
    end
  end

  defp fetch_analytics(%{platform: "twitter"} = account, post_platform) do
    case TwitterClient.get_tweet_metrics(account.access_token, post_platform.platform_post_id) do
      {:ok, metrics} ->
        {:ok,
         %{
           impressions: metrics.impressions,
           engagements:
             (metrics.likes || 0) + (metrics.retweets || 0) + (metrics.replies || 0),
           likes: metrics.likes,
           comments: metrics.replies,
           shares: metrics.retweets,
           clicks: metrics.clicks,
           raw_data: metrics.raw
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_analytics(%{platform: platform}, _post_platform) do
    {:error, "Analytics for #{platform} not yet implemented"}
  end
end
