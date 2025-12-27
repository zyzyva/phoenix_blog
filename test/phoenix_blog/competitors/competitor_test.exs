defmodule PhoenixBlog.Competitors.CompetitorTest do
  use PhoenixBlog.DataCase, async: true

  alias PhoenixBlog.Competitors.Competitor
  import PhoenixBlog.Fixtures

  describe "changeset/2" do
    setup do
      %{author: author_fixture()}
    end

    test "valid with required fields", %{author: author} do
      attrs = %{name: "Acme Corp", user_id: author.id}
      changeset = Competitor.changeset(%Competitor{}, attrs)
      assert changeset.valid?
    end

    test "invalid without name", %{author: author} do
      attrs = %{user_id: author.id}
      changeset = Competitor.changeset(%Competitor{}, attrs)
      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without user_id" do
      attrs = %{name: "Acme Corp"}
      changeset = Competitor.changeset(%Competitor{}, attrs)
      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "valid with optional fields", %{author: author} do
      attrs = %{
        name: "Acme Corp",
        user_id: author.id,
        website_urls: ["https://acme.com"],
        social_urls: ["https://twitter.com/acme"],
        ad_page_ids: ["12345"],
        status: "active",
        metadata: %{"notes" => "Main competitor"}
      }

      changeset = Competitor.changeset(%Competitor{}, attrs)
      assert changeset.valid?
    end

    test "validates status inclusion", %{author: author} do
      attrs = %{name: "Acme Corp", user_id: author.id, status: "invalid"}
      changeset = Competitor.changeset(%Competitor{}, attrs)
      refute changeset.valid?
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end

    test "validates status active", %{author: author} do
      attrs = %{name: "Acme Corp", user_id: author.id, status: "active"}
      changeset = Competitor.changeset(%Competitor{}, attrs)
      assert changeset.valid?
    end

    test "validates status paused", %{author: author} do
      attrs = %{name: "Acme Corp", user_id: author.id, status: "paused"}
      changeset = Competitor.changeset(%Competitor{}, attrs)
      assert changeset.valid?
    end

    test "validates website_urls format", %{author: author} do
      attrs = %{name: "Acme Corp", user_id: author.id, website_urls: ["not-a-url"]}
      changeset = Competitor.changeset(%Competitor{}, attrs)
      refute changeset.valid?
      assert %{website_urls: [msg]} = errors_on(changeset)
      assert msg =~ "invalid URLs"
    end

    test "validates social_urls format", %{author: author} do
      attrs = %{name: "Acme Corp", user_id: author.id, social_urls: ["bad-url"]}
      changeset = Competitor.changeset(%Competitor{}, attrs)
      refute changeset.valid?
      assert %{social_urls: [msg]} = errors_on(changeset)
      assert msg =~ "invalid URLs"
    end

    test "accepts valid URLs", %{author: author} do
      attrs = %{
        name: "Acme Corp",
        user_id: author.id,
        website_urls: ["https://acme.com", "http://blog.acme.com"],
        social_urls: ["https://twitter.com/acme", "https://facebook.com/acme"]
      }

      changeset = Competitor.changeset(%Competitor{}, attrs)
      assert changeset.valid?
    end

    test "defaults to empty arrays", %{author: author} do
      attrs = %{name: "Acme Corp", user_id: author.id}
      changeset = Competitor.changeset(%Competitor{}, attrs)
      competitor = Ecto.Changeset.apply_changes(changeset)
      assert competitor.website_urls == []
      assert competitor.social_urls == []
      assert competitor.ad_page_ids == []
    end

    test "defaults status to active", %{author: author} do
      attrs = %{name: "Acme Corp", user_id: author.id}
      changeset = Competitor.changeset(%Competitor{}, attrs)
      competitor = Ecto.Changeset.apply_changes(changeset)
      assert competitor.status == "active"
    end
  end

  describe "active?/1" do
    test "returns true for active competitor" do
      assert Competitor.active?(%Competitor{status: "active"})
    end

    test "returns false for paused competitor" do
      refute Competitor.active?(%Competitor{status: "paused"})
    end
  end

  describe "status_values/0" do
    test "returns valid status values" do
      assert Competitor.status_values() == ~w(active paused)
    end
  end
end
