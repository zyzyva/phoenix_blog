defmodule PhoenixBlog.CompetitorsTest do
  use PhoenixBlog.DataCase, async: true

  alias PhoenixBlog.Competitors
  import PhoenixBlog.Fixtures

  describe "list_competitors/2" do
    test "returns all competitors for a user" do
      author = author_fixture()
      competitor1 = competitor_fixture(author: author, name: "Alpha Corp")
      competitor2 = competitor_fixture(author: author, name: "Beta Inc")

      result = Competitors.list_competitors(author.id)

      assert length(result) == 2
      assert Enum.map(result, & &1.id) == [competitor1.id, competitor2.id]
    end

    test "returns competitors ordered by name" do
      author = author_fixture()
      _c2 = competitor_fixture(author: author, name: "Zebra Corp")
      _c1 = competitor_fixture(author: author, name: "Alpha Inc")

      result = Competitors.list_competitors(author.id)

      assert [first, second] = result
      assert first.name == "Alpha Inc"
      assert second.name == "Zebra Corp"
    end

    test "does not return competitors from other users" do
      author1 = author_fixture()
      author2 = author_fixture()
      _competitor1 = competitor_fixture(author: author1)
      _competitor2 = competitor_fixture(author: author2)

      result = Competitors.list_competitors(author1.id)

      assert length(result) == 1
    end

    test "filters by status when provided" do
      author = author_fixture()
      active = competitor_fixture(author: author, status: "active")
      _paused = competitor_fixture(author: author, status: "paused")

      result = Competitors.list_competitors(author.id, status: "active")

      assert length(result) == 1
      assert hd(result).id == active.id
    end

    test "returns empty list when no competitors" do
      author = author_fixture()
      assert Competitors.list_competitors(author.id) == []
    end
  end

  describe "get_competitor!/1" do
    test "returns the competitor with given id" do
      competitor = competitor_fixture()
      assert Competitors.get_competitor!(competitor.id).id == competitor.id
    end

    test "raises when competitor does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Competitors.get_competitor!(0)
      end
    end
  end

  describe "get_competitor!/2" do
    test "returns the competitor scoped to user" do
      author = author_fixture()
      competitor = competitor_fixture(author: author)

      result = Competitors.get_competitor!(author.id, competitor.id)
      assert result.id == competitor.id
    end

    test "raises when competitor belongs to different user" do
      author1 = author_fixture()
      author2 = author_fixture()
      competitor = competitor_fixture(author: author1)

      assert_raise Ecto.NoResultsError, fn ->
        Competitors.get_competitor!(author2.id, competitor.id)
      end
    end
  end

  describe "get_competitor_by_name/2" do
    test "returns the competitor with given name" do
      author = author_fixture()
      competitor = competitor_fixture(author: author, name: "Unique Name")

      result = Competitors.get_competitor_by_name(author.id, "Unique Name")
      assert result.id == competitor.id
    end

    test "returns nil when name not found" do
      author = author_fixture()
      assert Competitors.get_competitor_by_name(author.id, "Nonexistent") == nil
    end

    test "does not return competitor from different user" do
      author1 = author_fixture()
      author2 = author_fixture()
      _competitor = competitor_fixture(author: author1, name: "Shared Name")

      assert Competitors.get_competitor_by_name(author2.id, "Shared Name") == nil
    end
  end

  describe "create_competitor/1" do
    test "creates competitor with valid attrs" do
      author = author_fixture()

      attrs = %{
        name: "New Competitor",
        user_id: author.id,
        website_urls: ["https://example.com"],
        social_urls: ["https://twitter.com/example"]
      }

      assert {:ok, competitor} = Competitors.create_competitor(attrs)
      assert competitor.name == "New Competitor"
      assert competitor.website_urls == ["https://example.com"]
      assert competitor.status == "active"
    end

    test "returns error with invalid attrs" do
      assert {:error, changeset} = Competitors.create_competitor(%{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "update_competitor/2" do
    test "updates competitor with valid attrs" do
      competitor = competitor_fixture(name: "Old Name")

      assert {:ok, updated} = Competitors.update_competitor(competitor, %{name: "New Name"})
      assert updated.name == "New Name"
    end

    test "returns error with invalid attrs" do
      competitor = competitor_fixture()

      assert {:error, changeset} = Competitors.update_competitor(competitor, %{status: "invalid"})
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "pause_competitor/1" do
    test "sets status to paused" do
      competitor = competitor_fixture(status: "active")

      assert {:ok, paused} = Competitors.pause_competitor(competitor)
      assert paused.status == "paused"
    end
  end

  describe "activate_competitor/1" do
    test "sets status to active" do
      competitor = competitor_fixture(status: "paused")

      assert {:ok, activated} = Competitors.activate_competitor(competitor)
      assert activated.status == "active"
    end
  end

  describe "delete_competitor/1" do
    test "deletes the competitor" do
      competitor = competitor_fixture()

      assert {:ok, _} = Competitors.delete_competitor(competitor)

      assert_raise Ecto.NoResultsError, fn ->
        Competitors.get_competitor!(competitor.id)
      end
    end
  end

  describe "change_competitor/2" do
    test "returns a changeset" do
      competitor = competitor_fixture()
      changeset = Competitors.change_competitor(competitor)
      assert %Ecto.Changeset{} = changeset
    end

    test "returns a changeset with changes" do
      competitor = competitor_fixture()
      changeset = Competitors.change_competitor(competitor, %{name: "New Name"})
      assert changeset.changes == %{name: "New Name"}
    end
  end

  describe "add_social_url/2" do
    test "adds a new social URL" do
      competitor = competitor_fixture(social_urls: ["https://twitter.com/test"])

      assert {:ok, updated} = Competitors.add_social_url(competitor, "https://facebook.com/test")
      assert "https://facebook.com/test" in updated.social_urls
      assert "https://twitter.com/test" in updated.social_urls
    end

    test "does not duplicate existing URL" do
      competitor = competitor_fixture(social_urls: ["https://twitter.com/test"])

      assert {:ok, updated} = Competitors.add_social_url(competitor, "https://twitter.com/test")
      assert length(updated.social_urls) == 1
    end
  end

  describe "add_ad_page_id/2" do
    test "adds a new page ID" do
      competitor = competitor_fixture(ad_page_ids: ["123"])

      assert {:ok, updated} = Competitors.add_ad_page_id(competitor, "456")
      assert "456" in updated.ad_page_ids
      assert "123" in updated.ad_page_ids
    end

    test "does not duplicate existing ID" do
      competitor = competitor_fixture(ad_page_ids: ["123"])

      assert {:ok, updated} = Competitors.add_ad_page_id(competitor, "123")
      assert length(updated.ad_page_ids) == 1
    end
  end

  describe "count_by_status/1" do
    test "returns count of competitors grouped by status" do
      author = author_fixture()
      competitor_fixture(author: author, status: "active")
      competitor_fixture(author: author, status: "active")
      competitor_fixture(author: author, status: "paused")

      result = Competitors.count_by_status(author.id)

      assert result["active"] == 2
      assert result["paused"] == 1
    end

    test "returns empty map when no competitors" do
      author = author_fixture()
      assert Competitors.count_by_status(author.id) == %{}
    end
  end

  describe "active_competitors/1" do
    test "returns only active competitors" do
      author = author_fixture()
      active = competitor_fixture(author: author, status: "active")
      _paused = competitor_fixture(author: author, status: "paused")

      result = Competitors.active_competitors(author.id)

      assert length(result) == 1
      assert hd(result).id == active.id
    end
  end
end
