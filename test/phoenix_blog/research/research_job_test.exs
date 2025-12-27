defmodule PhoenixBlog.Research.ResearchJobTest do
  use PhoenixBlog.DataCase, async: true

  alias PhoenixBlog.Research.ResearchJob
  import PhoenixBlog.Fixtures

  describe "changeset/2" do
    setup do
      author = author_fixture()
      competitor = competitor_fixture(author: author)
      %{author: author, competitor: competitor}
    end

    test "valid with required fields", %{author: author} do
      attrs = %{job_type: "social_scrape", user_id: author.id}
      changeset = ResearchJob.changeset(%ResearchJob{}, attrs)
      assert changeset.valid?
    end

    test "invalid without job_type", %{author: author} do
      attrs = %{user_id: author.id}
      changeset = ResearchJob.changeset(%ResearchJob{}, attrs)
      refute changeset.valid?
      assert %{job_type: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without user_id" do
      attrs = %{job_type: "social_scrape"}
      changeset = ResearchJob.changeset(%ResearchJob{}, attrs)
      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates job_type inclusion", %{author: author} do
      attrs = %{job_type: "invalid_type", user_id: author.id}
      changeset = ResearchJob.changeset(%ResearchJob{}, attrs)
      refute changeset.valid?
      assert %{job_type: ["is invalid"]} = errors_on(changeset)
    end

    test "accepts all valid job types", %{author: author} do
      for job_type <- ~w(social_scrape ad_library comment_analysis review_analysis) do
        attrs = %{job_type: job_type, user_id: author.id}
        changeset = ResearchJob.changeset(%ResearchJob{}, attrs)
        assert changeset.valid?, "Expected #{job_type} to be valid"
      end
    end

    test "validates status inclusion", %{author: author} do
      attrs = %{job_type: "social_scrape", user_id: author.id, status: "invalid"}
      changeset = ResearchJob.changeset(%ResearchJob{}, attrs)
      refute changeset.valid?
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end

    test "accepts all valid statuses", %{author: author} do
      for status <- ~w(pending running completed failed) do
        attrs = %{job_type: "social_scrape", user_id: author.id, status: status}
        changeset = ResearchJob.changeset(%ResearchJob{}, attrs)
        assert changeset.valid?, "Expected status #{status} to be valid"
      end
    end

    test "valid with competitor", %{author: author, competitor: competitor} do
      attrs = %{job_type: "social_scrape", user_id: author.id, competitor_id: competitor.id}
      changeset = ResearchJob.changeset(%ResearchJob{}, attrs)
      assert changeset.valid?
    end

    test "valid with all optional fields", %{author: author, competitor: competitor} do
      attrs = %{
        job_type: "social_scrape",
        user_id: author.id,
        competitor_id: competitor.id,
        status: "running",
        external_job_id: "apify_run_123",
        input_params: %{"urls" => ["https://example.com"]},
        results: %{"items" => []},
        error_message: nil,
        cost: Decimal.new("0.05"),
        started_at: DateTime.utc_now(),
        completed_at: nil
      }

      changeset = ResearchJob.changeset(%ResearchJob{}, attrs)
      assert changeset.valid?
    end

    test "defaults status to pending", %{author: author} do
      attrs = %{job_type: "social_scrape", user_id: author.id}
      changeset = ResearchJob.changeset(%ResearchJob{}, attrs)
      job = Ecto.Changeset.apply_changes(changeset)
      assert job.status == "pending"
    end
  end

  describe "start_changeset/1" do
    test "sets status to running and started_at" do
      job = %ResearchJob{status: "pending"}
      changeset = ResearchJob.start_changeset(job)

      assert Ecto.Changeset.get_change(changeset, :status) == "running"
      assert Ecto.Changeset.get_change(changeset, :started_at)
    end
  end

  describe "complete_changeset/2" do
    test "sets status to completed with results" do
      job = %ResearchJob{status: "running"}
      results = %{"items" => [%{"text" => "Sample"}]}
      changeset = ResearchJob.complete_changeset(job, results)

      assert Ecto.Changeset.get_change(changeset, :status) == "completed"
      assert Ecto.Changeset.get_change(changeset, :results) == results
      assert Ecto.Changeset.get_change(changeset, :completed_at)
    end
  end

  describe "fail_changeset/2" do
    test "sets status to failed with error message" do
      job = %ResearchJob{status: "running"}
      changeset = ResearchJob.fail_changeset(job, "API rate limited")

      assert Ecto.Changeset.get_change(changeset, :status) == "failed"
      assert Ecto.Changeset.get_change(changeset, :error_message) == "API rate limited"
      assert Ecto.Changeset.get_change(changeset, :completed_at)
    end
  end

  describe "running?/1" do
    test "returns true for running job" do
      assert ResearchJob.running?(%ResearchJob{status: "running"})
    end

    test "returns false for pending job" do
      refute ResearchJob.running?(%ResearchJob{status: "pending"})
    end

    test "returns false for completed job" do
      refute ResearchJob.running?(%ResearchJob{status: "completed"})
    end
  end

  describe "completed?/1" do
    test "returns true for completed job" do
      assert ResearchJob.completed?(%ResearchJob{status: "completed"})
    end

    test "returns false for running job" do
      refute ResearchJob.completed?(%ResearchJob{status: "running"})
    end
  end

  describe "job_types/0" do
    test "returns valid job types" do
      assert ResearchJob.job_types() == ~w(social_scrape ad_library comment_analysis review_analysis)
    end
  end

  describe "status_values/0" do
    test "returns valid status values" do
      assert ResearchJob.status_values() == ~w(pending running completed failed)
    end
  end
end
