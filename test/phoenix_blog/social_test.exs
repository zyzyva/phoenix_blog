defmodule PhoenixBlog.SocialTest do
  use PhoenixBlog.DataCase, async: true

  alias PhoenixBlog.Social
  import PhoenixBlog.Fixtures

  # ============================================================================
  # Account Tests
  # ============================================================================

  describe "list_accounts/1" do
    test "returns all active accounts for a user" do
      author = author_fixture()
      account1 = social_account_fixture(author: author, platform: "twitter")
      account2 = social_account_fixture(author: author, platform: "linkedin")

      result = Social.list_accounts(author.id)

      assert length(result) == 2
      ids = Enum.map(result, & &1.id)
      assert account1.id in ids
      assert account2.id in ids
    end

    test "does not return accounts from other users" do
      author1 = author_fixture()
      author2 = author_fixture()
      _account1 = social_account_fixture(author: author1)
      _account2 = social_account_fixture(author: author2)

      result = Social.list_accounts(author1.id)

      assert length(result) == 1
    end

    test "does not return revoked accounts" do
      author = author_fixture()
      _active = social_account_fixture(author: author, status: "active")
      _revoked = social_account_fixture(author: author, status: "revoked")

      result = Social.list_accounts(author.id)

      assert length(result) == 1
    end

    test "returns empty list when no accounts" do
      author = author_fixture()
      assert Social.list_accounts(author.id) == []
    end
  end

  describe "list_accounts_by_platform/2" do
    test "returns only accounts for specified platform" do
      author = author_fixture()
      twitter = social_account_fixture(author: author, platform: "twitter")
      _linkedin = social_account_fixture(author: author, platform: "linkedin")

      result = Social.list_accounts_by_platform(author.id, "twitter")

      assert length(result) == 1
      assert hd(result).id == twitter.id
    end
  end

  describe "get_account!/1" do
    test "returns the account with given id" do
      account = social_account_fixture()
      assert Social.get_account!(account.id).id == account.id
    end

    test "raises when account does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Social.get_account!(0)
      end
    end
  end

  describe "get_account_by_platform_id/2" do
    test "returns account by platform and platform_user_id" do
      account = social_account_fixture(platform: "twitter", platform_user_id: "12345")

      result = Social.get_account_by_platform_id("twitter", "12345")

      assert result.id == account.id
    end

    test "returns nil when not found" do
      assert Social.get_account_by_platform_id("twitter", "nonexistent") == nil
    end
  end

  describe "connect_account/2" do
    test "creates a new account" do
      author = author_fixture()

      attrs = %{
        platform: "twitter",
        platform_user_id: "new_user_123",
        platform_username: "newuser",
        access_token: <<1, 2, 3, 4>>
      }

      assert {:ok, account} = Social.connect_account(author.id, attrs)
      assert account.platform == "twitter"
      assert account.platform_user_id == "new_user_123"
      assert account.user_id == author.id
    end
  end

  describe "update_account_tokens/2" do
    test "updates tokens" do
      account = social_account_fixture()
      new_token = <<10, 11, 12>>

      assert {:ok, updated} =
               Social.update_account_tokens(account, %{
                 access_token: new_token,
                 status: "active"
               })

      assert updated.access_token == new_token
    end
  end

  describe "revoke_account/1" do
    test "sets status to revoked" do
      account = social_account_fixture(status: "active")

      assert {:ok, revoked} = Social.revoke_account(account)
      assert revoked.status == "revoked"
    end
  end

  describe "delete_account/1" do
    test "deletes the account" do
      account = social_account_fixture()

      assert {:ok, _} = Social.delete_account(account)

      assert_raise Ecto.NoResultsError, fn ->
        Social.get_account!(account.id)
      end
    end
  end

  # ============================================================================
  # Post Tests
  # ============================================================================

  describe "list_posts/2" do
    test "returns all posts for a user" do
      author = author_fixture()
      post1 = social_post_fixture(author: author, content_text: "Post 1")
      post2 = social_post_fixture(author: author, content_text: "Post 2")

      result = Social.list_posts(author.id)

      assert length(result) == 2
      ids = Enum.map(result, & &1.id)
      assert post1.id in ids
      assert post2.id in ids
    end

    test "does not return posts from other users" do
      author1 = author_fixture()
      author2 = author_fixture()
      _post1 = social_post_fixture(author: author1)
      _post2 = social_post_fixture(author: author2)

      result = Social.list_posts(author1.id)

      assert length(result) == 1
    end

    test "filters by status" do
      author = author_fixture()
      draft = social_post_fixture(author: author, status: "draft")
      _published = social_post_fixture(author: author, status: "published")

      result = Social.list_posts(author.id, status: "draft")

      assert length(result) == 1
      assert hd(result).id == draft.id
    end

    test "respects limit option" do
      author = author_fixture()
      for _ <- 1..5, do: social_post_fixture(author: author)

      result = Social.list_posts(author.id, limit: 3)

      assert length(result) == 3
    end

    test "respects offset option" do
      author = author_fixture()
      for _ <- 1..5, do: social_post_fixture(author: author)

      result = Social.list_posts(author.id, limit: 10, offset: 3)

      assert length(result) == 2
    end

    test "returns empty list when no posts" do
      author = author_fixture()
      assert Social.list_posts(author.id) == []
    end
  end

  describe "get_post!/1" do
    test "returns the post with associations" do
      post = social_post_fixture()
      result = Social.get_post!(post.id)
      assert result.id == post.id
      assert Ecto.assoc_loaded?(result.post_platforms)
    end

    test "raises when post does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Social.get_post!(0)
      end
    end
  end

  describe "create_post/2" do
    test "creates a post with valid attrs" do
      author = author_fixture()

      attrs = %{
        content_text: "Hello world!",
        content_type: "text"
      }

      assert {:ok, post} = Social.create_post(author.id, attrs)
      assert post.content_text == "Hello world!"
      assert post.user_id == author.id
      assert post.status == "draft"
    end

    test "returns error with invalid attrs" do
      author = author_fixture()
      assert {:error, changeset} = Social.create_post(author.id, %{})
      assert %{content_text: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "update_post/2" do
    test "updates post with valid attrs" do
      post = social_post_fixture(content_text: "Old content")

      assert {:ok, updated} = Social.update_post(post, %{content_text: "New content"})
      assert updated.content_text == "New content"
    end

    test "returns error with invalid attrs" do
      post = social_post_fixture()

      assert {:error, changeset} = Social.update_post(post, %{status: "invalid"})
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "schedule_post/2" do
    test "schedules post for future" do
      post = social_post_fixture(status: "draft")
      future = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)

      assert {:ok, scheduled} = Social.schedule_post(post, future)
      assert scheduled.status == "scheduled"
      assert scheduled.scheduled_for
    end
  end

  describe "delete_post/1" do
    test "deletes the post" do
      post = social_post_fixture()

      assert {:ok, _} = Social.delete_post(post)

      assert_raise Ecto.NoResultsError, fn ->
        Social.get_post!(post.id)
      end
    end
  end

  describe "change_post/2" do
    test "returns a changeset" do
      post = social_post_fixture()
      changeset = Social.change_post(post)
      assert %Ecto.Changeset{} = changeset
    end
  end

  # ============================================================================
  # Stats Tests
  # ============================================================================

  describe "count_posts_by_status/1" do
    test "returns counts grouped by status" do
      author = author_fixture()
      social_post_fixture(author: author, status: "draft")
      social_post_fixture(author: author, status: "draft")
      social_post_fixture(author: author, status: "published")

      result = Social.count_posts_by_status(author.id)

      assert result["draft"] == 2
      assert result["published"] == 1
    end

    test "returns empty map when no posts" do
      author = author_fixture()
      assert Social.count_posts_by_status(author.id) == %{}
    end
  end

  describe "count_accounts_by_platform/1" do
    test "returns counts grouped by platform" do
      author = author_fixture()
      social_account_fixture(author: author, platform: "twitter")
      social_account_fixture(author: author, platform: "twitter")
      social_account_fixture(author: author, platform: "linkedin")

      result = Social.count_accounts_by_platform(author.id)

      assert result["twitter"] == 2
      assert result["linkedin"] == 1
    end

    test "returns empty map when no accounts" do
      author = author_fixture()
      assert Social.count_accounts_by_platform(author.id) == %{}
    end
  end
end
