defmodule PhoenixBlog.Social.Workers.ScheduledPublisherWorker do
  @moduledoc """
  Cron worker that checks for scheduled posts ready to publish.
  Runs every minute.
  """
  use Oban.Worker, queue: :scheduled

  alias PhoenixBlog.Social

  @impl Oban.Worker
  def perform(_job) do
    posts = Social.list_scheduled_posts()

    Enum.each(posts, fn post ->
      Enum.each(post.post_platforms, fn post_platform ->
        %{post_platform_id: post_platform.id}
        |> PhoenixBlog.Social.Workers.PublishPostWorker.new()
        |> Oban.insert()
      end)
    end)

    :ok
  end
end
