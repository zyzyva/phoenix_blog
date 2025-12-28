defmodule PhoenixBlog.Social.PostPlatformTest do
  use PhoenixBlog.DataCase, async: true

  alias PhoenixBlog.Social.PostPlatform

  describe "changeset/2" do
    test "valid with required fields" do
      attrs = %{social_post_id: 1, social_account_id: 1}
      changeset = PostPlatform.changeset(%PostPlatform{}, attrs)
      assert changeset.valid?
    end

    test "invalid without social_post_id" do
      attrs = %{social_account_id: 1}
      changeset = PostPlatform.changeset(%PostPlatform{}, attrs)
      refute changeset.valid?
      assert %{social_post_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without social_account_id" do
      attrs = %{social_post_id: 1}
      changeset = PostPlatform.changeset(%PostPlatform{}, attrs)
      refute changeset.valid?
      assert %{social_account_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "valid with platform_specific_content" do
      attrs = %{
        social_post_id: 1,
        social_account_id: 1,
        platform_specific_content: %{"hashtags" => ["#marketing", "#growth"]}
      }

      changeset = PostPlatform.changeset(%PostPlatform{}, attrs)
      assert changeset.valid?
    end

    test "defaults status to pending" do
      attrs = %{social_post_id: 1, social_account_id: 1}
      changeset = PostPlatform.changeset(%PostPlatform{}, attrs)
      post_platform = Ecto.Changeset.apply_changes(changeset)
      assert post_platform.status == "pending"
    end

    test "defaults platform_specific_content to empty map" do
      attrs = %{social_post_id: 1, social_account_id: 1}
      changeset = PostPlatform.changeset(%PostPlatform{}, attrs)
      post_platform = Ecto.Changeset.apply_changes(changeset)
      assert post_platform.platform_specific_content == %{}
    end
  end

  describe "publish_changeset/2" do
    test "validates status inclusion" do
      post_platform = %PostPlatform{status: "pending"}
      changeset = PostPlatform.publish_changeset(post_platform, %{status: "invalid"})
      refute changeset.valid?
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end

    test "accepts all valid statuses" do
      for status <- ~w(pending publishing published failed) do
        post_platform = %PostPlatform{status: "pending"}
        changeset = PostPlatform.publish_changeset(post_platform, %{status: status})
        assert changeset.valid?, "Expected status #{status} to be valid"
      end
    end

    test "can update publishing details" do
      post_platform = %PostPlatform{status: "publishing"}
      published_at = DateTime.utc_now() |> DateTime.truncate(:second)

      changeset =
        PostPlatform.publish_changeset(post_platform, %{
          status: "published",
          platform_post_id: "post_123",
          platform_url: "https://twitter.com/user/status/123",
          published_at: published_at
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :status) == "published"
      assert Ecto.Changeset.get_change(changeset, :platform_post_id) == "post_123"
      assert Ecto.Changeset.get_change(changeset, :platform_url) == "https://twitter.com/user/status/123"
    end

    test "can record error message on failure" do
      post_platform = %PostPlatform{status: "publishing"}

      changeset =
        PostPlatform.publish_changeset(post_platform, %{
          status: "failed",
          error_message: "Rate limit exceeded"
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :error_message) == "Rate limit exceeded"
    end
  end

  describe "status_values/0" do
    test "returns valid status values" do
      assert PostPlatform.status_values() == ~w(pending publishing published failed)
    end
  end
end
