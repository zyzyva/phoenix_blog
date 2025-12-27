defmodule PhoenixBlog.ResearchTest do
  use PhoenixBlog.DataCase, async: true

  alias PhoenixBlog.Research
  import PhoenixBlog.Fixtures

  describe "list_tactics/1" do
    test "returns all tactics" do
      tactic1 = tactic_fixture(title: "Tactic A")
      tactic2 = tactic_fixture(title: "Tactic B")

      result = Research.list_tactics()

      assert length(result) == 2
      ids = Enum.map(result, & &1.id)
      assert tactic1.id in ids
      assert tactic2.id in ids
    end

    test "returns multiple tactics" do
      tactic_fixture(title: "First")
      tactic_fixture(title: "Second")

      result = Research.list_tactics()

      assert length(result) == 2
    end

    test "filters by status" do
      saved = tactic_fixture(status: "saved")
      _testing = tactic_fixture(status: "testing")

      result = Research.list_tactics(status: "saved")

      assert length(result) == 1
      assert hd(result).id == saved.id
    end

    test "filters by category" do
      content = tactic_fixture(category: "content")
      _seo = tactic_fixture(category: "seo")

      result = Research.list_tactics(category: "content")

      assert length(result) == 1
      assert hd(result).id == content.id
    end

    test "respects limit option" do
      for _ <- 1..5, do: tactic_fixture()

      result = Research.list_tactics(limit: 3)

      assert length(result) == 3
    end

    test "returns empty list when no tactics" do
      assert Research.list_tactics() == []
    end
  end

  describe "get_tactic!/1" do
    test "returns the tactic with given id" do
      tactic = tactic_fixture()
      assert Research.get_tactic!(tactic.id).id == tactic.id
    end

    test "raises when tactic does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Research.get_tactic!(0)
      end
    end
  end

  describe "create_tactic/1" do
    test "creates tactic with valid attrs" do
      attrs = %{
        title: "New Tactic",
        source_platform: "twitter",
        description: "A new marketing tactic",
        category: "social"
      }

      assert {:ok, tactic} = Research.create_tactic(attrs)
      assert tactic.title == "New Tactic"
      assert tactic.source_platform == "twitter"
      assert tactic.status == "saved"
    end

    test "returns error with invalid attrs" do
      assert {:error, changeset} = Research.create_tactic(%{})
      assert %{title: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "create_tactic_from_reddit/2" do
    test "creates tactic from Reddit post structure" do
      post = %{
        title: "Viral marketing strategy that worked",
        selftext: "Here's how I grew my audience...",
        permalink: "/r/marketing/comments/abc123",
        author: "marketingguru",
        score: 250,
        num_comments: 45
      }

      assert {:ok, tactic} = Research.create_tactic_from_reddit(post)
      assert tactic.title == "Viral marketing strategy that worked"
      assert tactic.description == "Here's how I grew my audience..."
      assert tactic.source_url == "/r/marketing/comments/abc123"
      assert tactic.source_platform == "reddit"
      assert tactic.source_author == "marketingguru"
      assert tactic.source_score == 250
      assert tactic.source_comments == 45
    end

    test "allows overriding default attrs" do
      post = %{
        title: "Test",
        selftext: "Content",
        permalink: "/r/test/123",
        author: "user",
        score: 10,
        num_comments: 5
      }

      assert {:ok, tactic} = Research.create_tactic_from_reddit(post, %{category: "seo"})
      assert tactic.category == "seo"
    end
  end

  describe "update_tactic/2" do
    test "updates tactic with valid attrs" do
      tactic = tactic_fixture(title: "Old Title")

      assert {:ok, updated} = Research.update_tactic(tactic, %{title: "New Title"})
      assert updated.title == "New Title"
    end

    test "returns error with invalid attrs" do
      tactic = tactic_fixture()

      assert {:error, changeset} = Research.update_tactic(tactic, %{status: "invalid"})
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "start_testing/2" do
    test "transitions tactic to testing status" do
      tactic = tactic_fixture(status: "saved")

      assert {:ok, updated} = Research.start_testing(tactic, "Test on 10 Instagram posts")
      assert updated.status == "testing"
      assert updated.test_plan == "Test on 10 Instagram posts"
      assert updated.test_started_at
    end
  end

  describe "complete_test/4" do
    test "transitions tactic to validated" do
      tactic = tactic_fixture(status: "testing")
      metrics = %{"engagement_rate" => 0.25}

      assert {:ok, updated} =
               Research.complete_test(
                 tactic,
                 "validated",
                 "Increased engagement by 25%",
                 metrics
               )

      assert updated.status == "validated"
      assert updated.test_results == "Increased engagement by 25%"
      assert updated.metrics == metrics
      assert updated.test_completed_at
    end

    test "transitions tactic to debunked" do
      tactic = tactic_fixture(status: "testing")

      assert {:ok, updated} =
               Research.complete_test(tactic, "debunked", "No improvement observed")

      assert updated.status == "debunked"
      assert updated.test_results == "No improvement observed"
    end
  end

  describe "archive_tactic/1" do
    test "sets status to archived" do
      tactic = tactic_fixture(status: "saved")

      assert {:ok, archived} = Research.archive_tactic(tactic)
      assert archived.status == "archived"
    end
  end

  describe "delete_tactic/1" do
    test "deletes the tactic" do
      tactic = tactic_fixture()

      assert {:ok, _} = Research.delete_tactic(tactic)

      assert_raise Ecto.NoResultsError, fn ->
        Research.get_tactic!(tactic.id)
      end
    end
  end

  describe "count_by_status/0" do
    test "returns counts grouped by status" do
      tactic_fixture(status: "saved")
      tactic_fixture(status: "saved")
      tactic_fixture(status: "testing")
      tactic_fixture(status: "validated")

      result = Research.count_by_status()

      assert result["saved"] == 2
      assert result["testing"] == 1
      assert result["validated"] == 1
    end

    test "returns empty map when no tactics" do
      assert Research.count_by_status() == %{}
    end
  end

  describe "validated_tactics/1" do
    test "returns only validated tactics" do
      validated = tactic_fixture(status: "validated")
      _saved = tactic_fixture(status: "saved")

      result = Research.validated_tactics()

      assert length(result) == 1
      assert hd(result).id == validated.id
    end

    test "filters by category" do
      validated_content = tactic_fixture(status: "validated", category: "content")
      _validated_seo = tactic_fixture(status: "validated", category: "seo")

      result = Research.validated_tactics(category: "content")

      assert length(result) == 1
      assert hd(result).id == validated_content.id
    end

    test "respects limit option" do
      for _ <- 1..5, do: tactic_fixture(status: "validated")

      result = Research.validated_tactics(limit: 2)

      assert length(result) == 2
    end
  end

  describe "debunked_tactics/1" do
    test "returns only debunked tactics" do
      debunked = tactic_fixture(status: "debunked")
      _saved = tactic_fixture(status: "saved")

      result = Research.debunked_tactics()

      assert length(result) == 1
      assert hd(result).id == debunked.id
    end

    test "respects limit option" do
      for _ <- 1..5, do: tactic_fixture(status: "debunked")

      result = Research.debunked_tactics(limit: 2)

      assert length(result) == 2
    end
  end

  describe "monitored_subreddits/0" do
    test "returns list of subreddits" do
      result = Research.monitored_subreddits()

      assert is_list(result)
      assert length(result) > 0
    end
  end

  describe "twitter_experts/0" do
    test "returns list of experts" do
      result = Research.twitter_experts()

      assert is_list(result)
      assert length(result) > 0
    end
  end

  describe "create_tactic_from_tweet/2" do
    test "creates tactic from tweet structure" do
      tweet = %{
        text: "Here's a marketing tip that changed everything for us...",
        url: "https://twitter.com/user/status/123",
        author_username: "marketingpro",
        metrics: %{like_count: 500}
      }

      assert {:ok, tactic} = Research.create_tactic_from_tweet(tweet)
      assert tactic.title == "Here's a marketing tip that changed everything for us..."
      assert tactic.description == tweet.text
      assert tactic.source_url == "https://twitter.com/user/status/123"
      assert tactic.source_platform == "twitter"
      assert tactic.source_author == "marketingpro"
      assert tactic.source_score == 500
    end

    test "truncates long titles to 100 chars" do
      long_text = String.duplicate("a", 150)

      tweet = %{
        text: long_text,
        url: "https://twitter.com/user/status/123",
        author_username: "user",
        metrics: %{like_count: 10}
      }

      assert {:ok, tactic} = Research.create_tactic_from_tweet(tweet)
      assert String.length(tactic.title) == 100
    end
  end
end
