defmodule PhoenixBlog.Social.Workers.PublishPostWorker do
  @moduledoc """
  Worker that publishes a post to a specific platform.
  """
  use Oban.Worker, queue: :publishing, max_attempts: 3

  alias PhoenixBlog.Social
  alias PhoenixBlog.Social.Clients.TwitterClient

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"post_platform_id" => post_platform_id}}) do
    post_platform = Social.get_post_platform!(post_platform_id)
    account = post_platform.social_account
    post = post_platform.social_post

    # Mark as publishing
    Social.mark_publishing(post_platform)

    case publish_to_platform(account, post) do
      {:ok, result} ->
        Social.mark_published(post_platform, result.id, result.url)
        Logger.info("Published post #{post.id} to #{account.platform}: #{result.id}")
        :ok

      {:error, reason} ->
        Social.mark_failed(post_platform, reason)
        Logger.error("Failed to publish post #{post.id} to #{account.platform}: #{reason}")
        {:error, reason}
    end
  end

  defp publish_to_platform(%{platform: "twitter"} = account, post) do
    TwitterClient.post(account.access_token, post.content_text)
  end

  defp publish_to_platform(%{platform: platform}, _post) do
    {:error, "Publishing to #{platform} not yet implemented"}
  end
end
