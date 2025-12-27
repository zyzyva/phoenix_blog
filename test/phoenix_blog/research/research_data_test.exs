defmodule PhoenixBlog.Research.ResearchDataTest do
  use PhoenixBlog.DataCase, async: true

  alias PhoenixBlog.Research.ResearchData
  import PhoenixBlog.Fixtures

  describe "changeset/2" do
    setup do
      author = author_fixture()
      job = research_job_fixture(author: author)
      %{author: author, job: job}
    end

    test "valid with required fields", %{author: author} do
      attrs = %{source_type: "facebook_post", user_id: author.id}
      changeset = ResearchData.changeset(%ResearchData{}, attrs)
      assert changeset.valid?
    end

    test "invalid without source_type", %{author: author} do
      attrs = %{user_id: author.id}
      changeset = ResearchData.changeset(%ResearchData{}, attrs)
      refute changeset.valid?
      assert %{source_type: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without user_id" do
      attrs = %{source_type: "facebook_post"}
      changeset = ResearchData.changeset(%ResearchData{}, attrs)
      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates source_type inclusion", %{author: author} do
      attrs = %{source_type: "invalid_type", user_id: author.id}
      changeset = ResearchData.changeset(%ResearchData{}, attrs)
      refute changeset.valid?
      assert %{source_type: ["is invalid"]} = errors_on(changeset)
    end

    test "accepts all valid source types", %{author: author} do
      for source_type <- ~w(facebook_post instagram_post tiktok_video ad comment review) do
        attrs = %{source_type: source_type, user_id: author.id}
        changeset = ResearchData.changeset(%ResearchData{}, attrs)
        assert changeset.valid?, "Expected #{source_type} to be valid"
      end
    end

    test "validates sentiment inclusion", %{author: author} do
      attrs = %{source_type: "facebook_post", user_id: author.id, sentiment: "invalid"}
      changeset = ResearchData.changeset(%ResearchData{}, attrs)
      refute changeset.valid?
      assert %{sentiment: ["is invalid"]} = errors_on(changeset)
    end

    test "accepts all valid sentiments", %{author: author} do
      for sentiment <- ~w(positive negative neutral mixed) do
        attrs = %{source_type: "facebook_post", user_id: author.id, sentiment: sentiment}
        changeset = ResearchData.changeset(%ResearchData{}, attrs)
        assert changeset.valid?, "Expected sentiment #{sentiment} to be valid"
      end
    end

    test "accepts nil sentiment", %{author: author} do
      attrs = %{source_type: "facebook_post", user_id: author.id, sentiment: nil}
      changeset = ResearchData.changeset(%ResearchData{}, attrs)
      assert changeset.valid?
    end

    test "valid with research_job", %{author: author, job: job} do
      attrs = %{source_type: "facebook_post", user_id: author.id, research_job_id: job.id}
      changeset = ResearchData.changeset(%ResearchData{}, attrs)
      assert changeset.valid?
    end

    test "valid with all optional fields", %{author: author, job: job} do
      attrs = %{
        source_type: "instagram_post",
        user_id: author.id,
        research_job_id: job.id,
        content: "This product is amazing! #love",
        metrics: %{"likes" => 500, "comments" => 25},
        sentiment: "positive",
        themes: ["product_praise", "enthusiasm"],
        source_url: "https://instagram.com/p/abc123",
        source_author: "happy_customer",
        source_date: DateTime.utc_now(),
        raw_data: %{"full_response" => %{}}
      }

      changeset = ResearchData.changeset(%ResearchData{}, attrs)
      assert changeset.valid?
    end

    test "defaults to empty arrays and maps", %{author: author} do
      attrs = %{source_type: "facebook_post", user_id: author.id}
      changeset = ResearchData.changeset(%ResearchData{}, attrs)
      data = Ecto.Changeset.apply_changes(changeset)
      assert data.themes == []
      assert data.metrics == %{}
      assert data.raw_data == %{}
    end
  end

  describe "positive?/1" do
    test "returns true for positive sentiment" do
      assert ResearchData.positive?(%ResearchData{sentiment: "positive"})
    end

    test "returns false for negative sentiment" do
      refute ResearchData.positive?(%ResearchData{sentiment: "negative"})
    end

    test "returns false for nil sentiment" do
      refute ResearchData.positive?(%ResearchData{sentiment: nil})
    end
  end

  describe "negative?/1" do
    test "returns true for negative sentiment" do
      assert ResearchData.negative?(%ResearchData{sentiment: "negative"})
    end

    test "returns false for positive sentiment" do
      refute ResearchData.negative?(%ResearchData{sentiment: "positive"})
    end
  end

  describe "source_types/0" do
    test "returns valid source types" do
      assert ResearchData.source_types() == ~w(facebook_post instagram_post tiktok_video ad comment review)
    end
  end

  describe "sentiment_values/0" do
    test "returns valid sentiment values" do
      assert ResearchData.sentiment_values() == ~w(positive negative neutral mixed)
    end
  end
end
