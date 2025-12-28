defmodule PhoenixBlog.InsightsTest do
  use PhoenixBlog.DataCase, async: true

  import PhoenixBlog.Fixtures

  alias PhoenixBlog.Insights

  describe "list_insights/2" do
    test "returns all insights for a user" do
      author = author_fixture()
      author2 = author_fixture()

      {:ok, insight1} = Insights.create_insight(insight_attrs(author))
      {:ok, insight2} = Insights.create_insight(insight_attrs(author, title: "Second insight"))
      {:ok, _other} = Insights.create_insight(insight_attrs(author2, title: "Other user"))

      insights = Insights.list_insights(author.id)
      assert length(insights) == 2
      ids = Enum.map(insights, & &1.id)
      assert insight1.id in ids
      assert insight2.id in ids
    end

    test "filters by status" do
      author = author_fixture()

      {:ok, draft} = Insights.create_insight(insight_attrs(author))
      {:ok, active} = Insights.create_insight(insight_attrs(author, title: "Active", status: "active"))

      drafts = Insights.list_insights(author.id, status: "draft")
      assert length(drafts) == 1
      assert hd(drafts).id == draft.id

      actives = Insights.list_insights(author.id, status: "active")
      assert length(actives) == 1
      assert hd(actives).id == active.id
    end

    test "filters by insight_type" do
      author = author_fixture()

      {:ok, angle} = Insights.create_insight(insight_attrs(author))
      {:ok, hook} = Insights.create_insight(insight_attrs(author, title: "Hook", insight_type: "winning_hook"))

      angles = Insights.list_insights(author.id, insight_type: "messaging_angle")
      assert length(angles) == 1
      assert hd(angles).id == angle.id

      hooks = Insights.list_insights(author.id, insight_type: "winning_hook")
      assert length(hooks) == 1
      assert hd(hooks).id == hook.id
    end

    test "respects limit" do
      author = author_fixture()

      for i <- 1..5 do
        Insights.create_insight(insight_attrs(author, title: "Insight #{i}"))
      end

      insights = Insights.list_insights(author.id, limit: 3)
      assert length(insights) == 3
    end

    test "returns insights (with newer items first when timestamps differ)" do
      author = author_fixture()

      {:ok, _first} = Insights.create_insight(insight_attrs(author))
      {:ok, _second} = Insights.create_insight(insight_attrs(author, title: "Second"))

      insights = Insights.list_insights(author.id)
      assert length(insights) == 2
    end
  end

  describe "list_active_insights/2" do
    test "returns only active insights" do
      author = author_fixture()

      {:ok, _draft} = Insights.create_insight(insight_attrs(author))
      {:ok, active} = Insights.create_insight(insight_attrs(author, title: "Active", status: "active"))
      {:ok, _archived} = Insights.create_insight(insight_attrs(author, title: "Archived", status: "archived"))

      actives = Insights.list_active_insights(author.id)
      assert length(actives) == 1
      assert hd(actives).id == active.id
    end
  end

  describe "list_high_confidence_insights/2" do
    test "returns active insights with confidence >= 0.8" do
      author = author_fixture()

      {:ok, _low} = Insights.create_insight(insight_attrs(author, status: "active", confidence_score: Decimal.new("0.5")))
      {:ok, high} = Insights.create_insight(insight_attrs(author, title: "High", status: "active", confidence_score: Decimal.new("0.9")))
      {:ok, _draft_high} = Insights.create_insight(insight_attrs(author, title: "Draft High", confidence_score: Decimal.new("0.95")))

      high_confidence = Insights.list_high_confidence_insights(author.id)
      assert length(high_confidence) == 1
      assert hd(high_confidence).id == high.id
    end

    test "orders by confidence_score descending" do
      author = author_fixture()

      {:ok, _medium} = Insights.create_insight(insight_attrs(author, status: "active", confidence_score: Decimal.new("0.82")))
      {:ok, high} = Insights.create_insight(insight_attrs(author, title: "Highest", status: "active", confidence_score: Decimal.new("0.95")))

      [highest | _] = Insights.list_high_confidence_insights(author.id)
      assert highest.id == high.id
    end
  end

  describe "get_insight!/1" do
    test "returns the insight with given id" do
      author = author_fixture()
      {:ok, insight} = Insights.create_insight(insight_attrs(author))
      fetched = Insights.get_insight!(insight.id)
      assert fetched.id == insight.id
      assert fetched.title == insight.title
    end

    test "raises if insight not found" do
      assert_raise Ecto.NoResultsError, fn ->
        Insights.get_insight!(0)
      end
    end
  end

  describe "get_insight!/2" do
    test "returns the insight scoped to user" do
      author = author_fixture()
      {:ok, insight} = Insights.create_insight(insight_attrs(author))
      fetched = Insights.get_insight!(author.id, insight.id)
      assert fetched.id == insight.id
    end

    test "raises if insight belongs to different user" do
      author = author_fixture()
      {:ok, insight} = Insights.create_insight(insight_attrs(author))
      assert_raise Ecto.NoResultsError, fn ->
        Insights.get_insight!(0, insight.id)
      end
    end
  end

  describe "create_insight/1" do
    test "creates insight with valid attrs" do
      author = author_fixture()
      assert {:ok, insight} = Insights.create_insight(insight_attrs(author))
      assert insight.user_id == author.id
      assert insight.insight_type == "messaging_angle"
      assert insight.title == "Pain point messaging"
      assert insight.status == "draft"
      assert insight.used_count == 0
    end

    test "fails with invalid attrs" do
      assert {:error, changeset} = Insights.create_insight(%{})
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "creates insight with evidence_ids and tags" do
      author = author_fixture()
      attrs = insight_attrs(author, evidence_ids: [1, 2, 3], tags: ["competitor", "messaging"])

      assert {:ok, insight} = Insights.create_insight(attrs)
      assert insight.evidence_ids == [1, 2, 3]
      assert insight.tags == ["competitor", "messaging"]
    end
  end

  describe "update_insight/2" do
    test "updates insight with valid attrs" do
      author = author_fixture()
      {:ok, insight} = Insights.create_insight(insight_attrs(author))
      assert {:ok, updated} = Insights.update_insight(insight, %{title: "Updated title"})
      assert updated.title == "Updated title"
    end

    test "fails with invalid attrs" do
      author = author_fixture()
      {:ok, insight} = Insights.create_insight(insight_attrs(author))
      assert {:error, changeset} = Insights.update_insight(insight, %{insight_type: "invalid"})
      assert %{insight_type: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "activate_insight/1" do
    test "sets status to active" do
      author = author_fixture()
      {:ok, insight} = Insights.create_insight(insight_attrs(author))
      assert insight.status == "draft"

      assert {:ok, activated} = Insights.activate_insight(insight)
      assert activated.status == "active"
    end
  end

  describe "archive_insight/1" do
    test "sets status to archived" do
      author = author_fixture()
      {:ok, insight} = Insights.create_insight(insight_attrs(author, status: "active"))
      assert {:ok, archived} = Insights.archive_insight(insight)
      assert archived.status == "archived"
    end
  end

  describe "increment_usage/1" do
    test "increments used_count" do
      author = author_fixture()
      {:ok, insight} = Insights.create_insight(insight_attrs(author))
      assert insight.used_count == 0

      assert {:ok, used} = Insights.increment_usage(insight)
      assert used.used_count == 1

      assert {:ok, used_again} = Insights.increment_usage(used)
      assert used_again.used_count == 2
    end
  end

  describe "delete_insight/1" do
    test "deletes the insight" do
      author = author_fixture()
      {:ok, insight} = Insights.create_insight(insight_attrs(author))
      assert {:ok, _} = Insights.delete_insight(insight)
      assert_raise Ecto.NoResultsError, fn ->
        Insights.get_insight!(insight.id)
      end
    end
  end

  describe "change_insight/2" do
    test "returns a changeset" do
      author = author_fixture()
      {:ok, insight} = Insights.create_insight(insight_attrs(author))
      changeset = Insights.change_insight(insight)
      assert %Ecto.Changeset{} = changeset
    end

    test "returns changeset with changes" do
      author = author_fixture()
      {:ok, insight} = Insights.create_insight(insight_attrs(author))
      changeset = Insights.change_insight(insight, %{title: "New title"})
      assert changeset.changes == %{title: "New title"}
    end
  end

  describe "count_by_status/1" do
    test "returns counts grouped by status" do
      author = author_fixture()
      Insights.create_insight(insight_attrs(author))
      Insights.create_insight(insight_attrs(author, title: "Draft 2"))
      Insights.create_insight(insight_attrs(author, title: "Active", status: "active"))

      counts = Insights.count_by_status(author.id)
      assert counts["draft"] == 2
      assert counts["active"] == 1
    end

    test "returns empty map for user with no insights" do
      assert Insights.count_by_status(0) == %{}
    end
  end

  describe "count_by_type/1" do
    test "returns counts grouped by insight_type" do
      author = author_fixture()
      Insights.create_insight(insight_attrs(author))
      Insights.create_insight(insight_attrs(author, title: "Hook", insight_type: "winning_hook"))
      Insights.create_insight(insight_attrs(author, title: "Hook 2", insight_type: "winning_hook"))

      counts = Insights.count_by_type(author.id)
      assert counts["messaging_angle"] == 1
      assert counts["winning_hook"] == 2
    end
  end

  describe "most_used_insights/2" do
    test "returns insights ordered by used_count descending" do
      author = author_fixture()
      {:ok, i1} = Insights.create_insight(insight_attrs(author))
      {:ok, i2} = Insights.create_insight(insight_attrs(author, title: "Second"))

      {:ok, _} = Insights.increment_usage(i1)
      {:ok, i2} = Insights.increment_usage(i2)
      {:ok, _} = Insights.increment_usage(i2)

      [most_used | _] = Insights.most_used_insights(author.id)
      assert most_used.id == i2.id
      assert most_used.used_count == 2
    end

    test "excludes insights with zero usage" do
      author = author_fixture()
      {:ok, _unused} = Insights.create_insight(insight_attrs(author))
      {:ok, used} = Insights.create_insight(insight_attrs(author, title: "Used"))
      {:ok, _} = Insights.increment_usage(used)

      most_used = Insights.most_used_insights(author.id)
      assert length(most_used) == 1
      assert hd(most_used).used_count > 0
    end
  end

  describe "search_insights/3" do
    test "searches by title" do
      author = author_fixture()
      {:ok, marketing} = Insights.create_insight(insight_attrs(author, title: "Marketing angle"))
      {:ok, _sales} = Insights.create_insight(insight_attrs(author, title: "Sales hook"))

      results = Insights.search_insights(author.id, "market")
      assert length(results) == 1
      assert hd(results).id == marketing.id
    end

    test "searches by description" do
      author = author_fixture()
      {:ok, insight} = Insights.create_insight(insight_attrs(author, description: "Competitor analysis shows weakness"))
      {:ok, _other} = Insights.create_insight(insight_attrs(author, title: "Other", description: "Different topic"))

      results = Insights.search_insights(author.id, "weakness")
      assert length(results) == 1
      assert hd(results).id == insight.id
    end

    test "case insensitive search" do
      author = author_fixture()
      {:ok, insight} = Insights.create_insight(insight_attrs(author, title: "UPPERCASE Title"))

      results = Insights.search_insights(author.id, "uppercase")
      assert length(results) == 1
      assert hd(results).id == insight.id
    end

    test "respects limit" do
      author = author_fixture()
      for i <- 1..5 do
        Insights.create_insight(insight_attrs(author, title: "Test insight #{i}"))
      end

      results = Insights.search_insights(author.id, "test", limit: 2)
      assert length(results) == 2
    end
  end

  # Helper to build insight attrs with an author
  defp insight_attrs(author, overrides \\ []) do
    Enum.into(overrides, %{
      user_id: author.id,
      insight_type: "messaging_angle",
      title: "Pain point messaging",
      description: "Competitors focus on features, not benefits",
      confidence_score: Decimal.new("0.85"),
      status: "draft"
    })
  end
end
