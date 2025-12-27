defmodule PhoenixBlog.Insights.InsightTest do
  use PhoenixBlog.DataCase, async: true

  alias PhoenixBlog.Insights.Insight
  import PhoenixBlog.Fixtures

  describe "changeset/2" do
    setup do
      %{author: author_fixture()}
    end

    test "valid with required fields", %{author: author} do
      attrs = %{insight_type: "messaging_angle", title: "Test Insight", user_id: author.id}
      changeset = Insight.changeset(%Insight{}, attrs)
      assert changeset.valid?
    end

    test "invalid without insight_type", %{author: author} do
      attrs = %{title: "Test Insight", user_id: author.id}
      changeset = Insight.changeset(%Insight{}, attrs)
      refute changeset.valid?
      assert %{insight_type: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without title", %{author: author} do
      attrs = %{insight_type: "messaging_angle", user_id: author.id}
      changeset = Insight.changeset(%Insight{}, attrs)
      refute changeset.valid?
      assert %{title: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without user_id" do
      attrs = %{insight_type: "messaging_angle", title: "Test Insight"}
      changeset = Insight.changeset(%Insight{}, attrs)
      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates insight_type inclusion", %{author: author} do
      attrs = %{insight_type: "invalid_type", title: "Test", user_id: author.id}
      changeset = Insight.changeset(%Insight{}, attrs)
      refute changeset.valid?
      assert %{insight_type: ["is invalid"]} = errors_on(changeset)
    end

    test "accepts all valid insight types", %{author: author} do
      for insight_type <- ~w(messaging_angle objection opportunity winning_hook competitor_weakness) do
        attrs = %{insight_type: insight_type, title: "Test", user_id: author.id}
        changeset = Insight.changeset(%Insight{}, attrs)
        assert changeset.valid?, "Expected #{insight_type} to be valid"
      end
    end

    test "validates status inclusion", %{author: author} do
      attrs = %{insight_type: "messaging_angle", title: "Test", user_id: author.id, status: "invalid"}
      changeset = Insight.changeset(%Insight{}, attrs)
      refute changeset.valid?
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end

    test "accepts all valid statuses", %{author: author} do
      for status <- ~w(draft active archived) do
        attrs = %{insight_type: "messaging_angle", title: "Test", user_id: author.id, status: status}
        changeset = Insight.changeset(%Insight{}, attrs)
        assert changeset.valid?, "Expected status #{status} to be valid"
      end
    end

    test "validates confidence_score range", %{author: author} do
      attrs = %{insight_type: "messaging_angle", title: "Test", user_id: author.id, confidence_score: Decimal.new("-0.1")}
      changeset = Insight.changeset(%Insight{}, attrs)
      refute changeset.valid?
      assert %{confidence_score: [_]} = errors_on(changeset)

      attrs = %{insight_type: "messaging_angle", title: "Test", user_id: author.id, confidence_score: Decimal.new("1.1")}
      changeset = Insight.changeset(%Insight{}, attrs)
      refute changeset.valid?
      assert %{confidence_score: [_]} = errors_on(changeset)
    end

    test "accepts valid confidence_scores", %{author: author} do
      for score <- ["0", "0.5", "1"] do
        attrs = %{insight_type: "messaging_angle", title: "Test", user_id: author.id, confidence_score: Decimal.new(score)}
        changeset = Insight.changeset(%Insight{}, attrs)
        assert changeset.valid?, "Expected confidence_score #{score} to be valid"
      end
    end

    test "valid with all optional fields", %{author: author} do
      attrs = %{
        insight_type: "opportunity",
        title: "Great Opportunity",
        description: "This is a great opportunity we discovered",
        evidence_ids: [1, 2, 3],
        confidence_score: Decimal.new("0.85"),
        tags: ["pricing", "value"],
        status: "active",
        used_count: 5,
        user_id: author.id
      }

      changeset = Insight.changeset(%Insight{}, attrs)
      assert changeset.valid?
    end

    test "defaults to empty arrays and draft status", %{author: author} do
      attrs = %{insight_type: "messaging_angle", title: "Test", user_id: author.id}
      changeset = Insight.changeset(%Insight{}, attrs)
      insight = Ecto.Changeset.apply_changes(changeset)
      assert insight.evidence_ids == []
      assert insight.tags == []
      assert insight.status == "draft"
      assert insight.used_count == 0
    end
  end

  describe "activate_changeset/1" do
    test "sets status to active" do
      insight = %Insight{status: "draft"}
      changeset = Insight.activate_changeset(insight)
      assert Ecto.Changeset.get_change(changeset, :status) == "active"
    end
  end

  describe "archive_changeset/1" do
    test "sets status to archived" do
      insight = %Insight{status: "active"}
      changeset = Insight.archive_changeset(insight)
      assert Ecto.Changeset.get_change(changeset, :status) == "archived"
    end
  end

  describe "increment_usage/1" do
    test "increments used_count by 1" do
      insight = %Insight{used_count: 5}
      changeset = Insight.increment_usage(insight)
      assert Ecto.Changeset.get_change(changeset, :used_count) == 6
    end

    test "increments from 0" do
      insight = %Insight{used_count: 0}
      changeset = Insight.increment_usage(insight)
      assert Ecto.Changeset.get_change(changeset, :used_count) == 1
    end
  end

  describe "insight_types/0" do
    test "returns valid insight types" do
      assert Insight.insight_types() == ~w(messaging_angle objection opportunity winning_hook competitor_weakness)
    end
  end

  describe "status_values/0" do
    test "returns valid status values" do
      assert Insight.status_values() == ~w(draft active archived)
    end
  end

  describe "active?/1" do
    test "returns true for active insight" do
      assert Insight.active?(%Insight{status: "active"})
    end

    test "returns false for draft insight" do
      refute Insight.active?(%Insight{status: "draft"})
    end

    test "returns false for archived insight" do
      refute Insight.active?(%Insight{status: "archived"})
    end
  end

  describe "high_confidence?/1" do
    test "returns true for score >= 0.8" do
      assert Insight.high_confidence?(%Insight{confidence_score: Decimal.new("0.8")})
      assert Insight.high_confidence?(%Insight{confidence_score: Decimal.new("0.9")})
      assert Insight.high_confidence?(%Insight{confidence_score: Decimal.new("1.0")})
    end

    test "returns false for score < 0.8" do
      refute Insight.high_confidence?(%Insight{confidence_score: Decimal.new("0.79")})
      refute Insight.high_confidence?(%Insight{confidence_score: Decimal.new("0.5")})
      refute Insight.high_confidence?(%Insight{confidence_score: Decimal.new("0")})
    end

    test "returns false for nil score" do
      refute Insight.high_confidence?(%Insight{confidence_score: nil})
    end
  end
end
