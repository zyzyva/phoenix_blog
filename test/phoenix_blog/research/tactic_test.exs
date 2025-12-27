defmodule PhoenixBlog.Research.TacticTest do
  use PhoenixBlog.DataCase, async: true

  alias PhoenixBlog.Research.Tactic

  describe "changeset/2" do
    test "valid with required fields" do
      attrs = %{title: "Test Tactic", source_platform: "reddit"}
      changeset = Tactic.changeset(%Tactic{}, attrs)
      assert changeset.valid?
    end

    test "invalid without title" do
      attrs = %{source_platform: "reddit"}
      changeset = Tactic.changeset(%Tactic{}, attrs)
      refute changeset.valid?
      assert %{title: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without source_platform" do
      attrs = %{title: "Test Tactic"}
      changeset = Tactic.changeset(%Tactic{}, attrs)
      refute changeset.valid?
      assert %{source_platform: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates status inclusion" do
      attrs = %{title: "Test", source_platform: "reddit", status: "invalid"}
      changeset = Tactic.changeset(%Tactic{}, attrs)
      refute changeset.valid?
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end

    test "accepts all valid statuses" do
      for status <- ~w(saved testing validated debunked archived) do
        attrs = %{title: "Test", source_platform: "reddit", status: status}
        changeset = Tactic.changeset(%Tactic{}, attrs)
        assert changeset.valid?, "Expected status #{status} to be valid"
      end
    end

    test "validates category inclusion" do
      attrs = %{title: "Test", source_platform: "reddit", category: "invalid"}
      changeset = Tactic.changeset(%Tactic{}, attrs)
      refute changeset.valid?
      assert %{category: [_]} = errors_on(changeset)
    end

    test "accepts all valid categories" do
      for category <- ~w(content seo paid_ads social email outreach growth_hack other) do
        attrs = %{title: "Test", source_platform: "reddit", category: category}
        changeset = Tactic.changeset(%Tactic{}, attrs)
        assert changeset.valid?, "Expected category #{category} to be valid"
      end
    end

    test "accepts nil category" do
      attrs = %{title: "Test", source_platform: "reddit", category: nil}
      changeset = Tactic.changeset(%Tactic{}, attrs)
      assert changeset.valid?
    end

    test "valid with all optional fields" do
      attrs = %{
        title: "Viral Hook Strategy",
        description: "Use emotion-triggering hooks in first 3 seconds",
        source_url: "https://reddit.com/r/marketing/post123",
        source_platform: "reddit",
        source_author: "marketingguru",
        status: "testing",
        category: "social",
        tags: ["viral", "hooks", "video"],
        platforms: ["tiktok", "instagram"],
        test_plan: "Test on 10 TikTok videos",
        test_results: nil,
        metrics: %{"views" => 1000},
        source_score: 250,
        source_comments: 45,
        notes: "Found in trending posts"
      }

      changeset = Tactic.changeset(%Tactic{}, attrs)
      assert changeset.valid?
    end

    test "defaults status to saved" do
      attrs = %{title: "Test", source_platform: "reddit"}
      changeset = Tactic.changeset(%Tactic{}, attrs)
      tactic = Ecto.Changeset.apply_changes(changeset)
      assert tactic.status == "saved"
    end

    test "defaults to empty arrays and maps" do
      attrs = %{title: "Test", source_platform: "reddit"}
      changeset = Tactic.changeset(%Tactic{}, attrs)
      tactic = Ecto.Changeset.apply_changes(changeset)
      assert tactic.tags == []
      assert tactic.platforms == []
      assert tactic.metrics == %{}
    end
  end

  describe "start_test_changeset/2" do
    test "sets status to testing and records test_plan and start time" do
      tactic = %Tactic{status: "saved"}
      changeset = Tactic.start_test_changeset(tactic, "Test on 10 posts")

      assert Ecto.Changeset.get_change(changeset, :status) == "testing"
      assert Ecto.Changeset.get_change(changeset, :test_plan) == "Test on 10 posts"
      assert Ecto.Changeset.get_change(changeset, :test_started_at)
    end
  end

  describe "complete_test_changeset/2" do
    test "sets status and records results for validated" do
      tactic = %Tactic{status: "testing"}

      changeset =
        Tactic.complete_test_changeset(tactic, %{
          status: "validated",
          test_results: "Increased engagement by 25%",
          metrics: %{"engagement_rate" => 0.25}
        })

      assert Ecto.Changeset.get_change(changeset, :status) == "validated"
      assert Ecto.Changeset.get_change(changeset, :test_results) == "Increased engagement by 25%"
      assert Ecto.Changeset.get_change(changeset, :metrics) == %{"engagement_rate" => 0.25}
      assert Ecto.Changeset.get_change(changeset, :test_completed_at)
    end

    test "sets status and records results for debunked" do
      tactic = %Tactic{status: "testing"}

      changeset =
        Tactic.complete_test_changeset(tactic, %{
          status: "debunked",
          test_results: "No significant improvement",
          notes: "Tested on 20 posts"
        })

      assert Ecto.Changeset.get_change(changeset, :status) == "debunked"
      assert Ecto.Changeset.get_change(changeset, :notes) == "Tested on 20 posts"
      assert Ecto.Changeset.get_change(changeset, :test_completed_at)
    end

    test "rejects invalid completion status" do
      tactic = %Tactic{status: "testing"}
      changeset = Tactic.complete_test_changeset(tactic, %{status: "saved"})

      refute changeset.valid?
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end
  end
end
