defmodule PhoenixBlog.Social.AnalyticsRecordTest do
  use PhoenixBlog.DataCase, async: true

  alias PhoenixBlog.Social.AnalyticsRecord

  describe "changeset/2" do
    test "valid with required fields" do
      attrs = %{
        fetched_at: DateTime.utc_now() |> DateTime.truncate(:second),
        social_post_platform_id: 1
      }

      changeset = AnalyticsRecord.changeset(%AnalyticsRecord{}, attrs)
      assert changeset.valid?
    end

    test "invalid without fetched_at" do
      attrs = %{social_post_platform_id: 1}
      changeset = AnalyticsRecord.changeset(%AnalyticsRecord{}, attrs)
      refute changeset.valid?
      assert %{fetched_at: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without social_post_platform_id" do
      attrs = %{fetched_at: DateTime.utc_now()}
      changeset = AnalyticsRecord.changeset(%AnalyticsRecord{}, attrs)
      refute changeset.valid?
      assert %{social_post_platform_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "valid with all optional metrics" do
      attrs = %{
        fetched_at: DateTime.utc_now() |> DateTime.truncate(:second),
        social_post_platform_id: 1,
        impressions: 1000,
        engagements: 150,
        likes: 100,
        comments: 25,
        shares: 15,
        clicks: 50,
        reach: 800,
        video_views: 500,
        raw_data: %{"source" => "api"}
      }

      changeset = AnalyticsRecord.changeset(%AnalyticsRecord{}, attrs)
      assert changeset.valid?
    end

    test "defaults raw_data to empty map" do
      attrs = %{
        fetched_at: DateTime.utc_now() |> DateTime.truncate(:second),
        social_post_platform_id: 1
      }

      changeset = AnalyticsRecord.changeset(%AnalyticsRecord{}, attrs)
      record = Ecto.Changeset.apply_changes(changeset)
      assert record.raw_data == %{}
    end
  end
end
