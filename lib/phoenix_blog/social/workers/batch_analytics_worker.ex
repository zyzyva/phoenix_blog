defmodule PhoenixBlog.Social.Workers.BatchAnalyticsWorker do
  @moduledoc """
  Cron worker that fetches analytics for recently published posts.
  Runs hourly.
  """
  use Oban.Worker, queue: :analytics

  import Ecto.Query
  alias PhoenixBlog.Repo
  alias PhoenixBlog.Social.PostPlatform

  @impl Oban.Worker
  def perform(_job) do
    # Find all published posts from the last 7 days
    since = DateTime.utc_now() |> DateTime.add(-7, :day)

    post_platforms =
      PostPlatform
      |> where([pp], pp.status == "published")
      |> where([pp], pp.published_at >= ^since)
      |> Repo.all()

    Enum.each(post_platforms, fn pp ->
      %{post_platform_id: pp.id}
      |> PhoenixBlog.Social.Workers.FetchAnalyticsWorker.new()
      |> Oban.insert()
    end)

    :ok
  end
end
