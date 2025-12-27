defmodule PhoenixBlog.Fixtures do
  @moduledoc """
  Test fixtures for creating test data.
  """

  alias PhoenixBlog.Repo
  alias PhoenixBlog.Blog

  def author_fixture(attrs \\ %{}) do
    {:ok, author} =
      attrs
      |> Enum.into(%{
        name: "Test Author #{System.unique_integer()}",
        email: "test#{System.unique_integer()}@example.com",
        external_id: "user_#{System.unique_integer()}"
      })
      |> Blog.get_or_create_author()

    author
  end

  def competitor_fixture(attrs \\ %{}) do
    author = attrs[:author] || author_fixture()

    {:ok, competitor} =
      %PhoenixBlog.Competitors.Competitor{}
      |> PhoenixBlog.Competitors.Competitor.changeset(
        Enum.into(attrs, %{
          name: "Competitor #{System.unique_integer()}",
          user_id: author.id
        })
      )
      |> Repo.insert()

    competitor
  end

  def research_job_fixture(attrs \\ %{}) do
    author = attrs[:author] || author_fixture()
    competitor = attrs[:competitor]

    {:ok, job} =
      %PhoenixBlog.Research.ResearchJob{}
      |> PhoenixBlog.Research.ResearchJob.changeset(
        Enum.into(attrs, %{
          job_type: "social_scrape",
          user_id: author.id,
          competitor_id: competitor && competitor.id
        })
      )
      |> Repo.insert()

    job
  end

  def research_data_fixture(attrs \\ %{}) do
    author = attrs[:author] || author_fixture()
    job = attrs[:research_job]

    {:ok, data} =
      %PhoenixBlog.Research.ResearchData{}
      |> PhoenixBlog.Research.ResearchData.changeset(
        Enum.into(attrs, %{
          source_type: "facebook_post",
          content: "Sample content",
          user_id: author.id,
          research_job_id: job && job.id
        })
      )
      |> Repo.insert()

    data
  end

  def insight_fixture(attrs \\ %{}) do
    author = attrs[:author] || author_fixture()

    {:ok, insight} =
      %PhoenixBlog.Insights.Insight{}
      |> PhoenixBlog.Insights.Insight.changeset(
        Enum.into(attrs, %{
          insight_type: "messaging_angle",
          title: "Test Insight #{System.unique_integer()}",
          user_id: author.id
        })
      )
      |> Repo.insert()

    insight
  end

  def content_generation_fixture(attrs \\ %{}) do
    author = attrs[:author] || author_fixture()
    insight = attrs[:insight]

    {:ok, generation} =
      %PhoenixBlog.Generations.ContentGeneration{}
      |> PhoenixBlog.Generations.ContentGeneration.changeset(
        Enum.into(attrs, %{
          content_type: "social_post",
          user_id: author.id,
          insight_id: insight && insight.id
        })
      )
      |> Repo.insert()

    generation
  end

  def webhook_fixture(attrs \\ %{}) do
    author = attrs[:author] || author_fixture()

    {:ok, webhook} =
      %PhoenixBlog.Delivery.Webhook{}
      |> PhoenixBlog.Delivery.Webhook.changeset(
        Enum.into(attrs, %{
          name: "Test Webhook #{System.unique_integer()}",
          url: "https://example.com/webhook",
          secret: :crypto.strong_rand_bytes(32),
          events: ["generation.completed"],
          user_id: author.id
        })
      )
      |> Repo.insert()

    webhook
  end

  def cost_entry_fixture(attrs \\ %{}) do
    author = attrs[:author] || author_fixture()

    {:ok, entry} =
      %PhoenixBlog.Costs.CostEntry{}
      |> PhoenixBlog.Costs.CostEntry.changeset(
        Enum.into(attrs, %{
          service: "huggingface",
          operation: "text_to_image",
          cost: Decimal.new("0.01"),
          user_id: author.id
        })
      )
      |> Repo.insert()

    entry
  end

  def tactic_fixture(attrs \\ %{}) do
    {:ok, tactic} =
      %PhoenixBlog.Research.Tactic{}
      |> PhoenixBlog.Research.Tactic.changeset(
        Enum.into(attrs, %{
          title: "Test Tactic #{System.unique_integer()}",
          source_platform: "reddit",
          description: "A marketing tactic to test",
          category: "content"
        })
      )
      |> Repo.insert()

    tactic
  end
end
