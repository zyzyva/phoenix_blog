defmodule PhoenixBlog.Social.PostTest do
  use PhoenixBlog.DataCase, async: true

  alias PhoenixBlog.Social.Post
  import PhoenixBlog.Fixtures

  describe "changeset/2" do
    setup do
      %{author: author_fixture()}
    end

    test "valid with required fields", %{author: author} do
      attrs = %{content_text: "Hello world!", user_id: author.id}
      changeset = Post.changeset(%Post{}, attrs)
      assert changeset.valid?
    end

    test "invalid without content_text", %{author: author} do
      attrs = %{user_id: author.id}
      changeset = Post.changeset(%Post{}, attrs)
      refute changeset.valid?
      assert %{content_text: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without user_id" do
      attrs = %{content_text: "Hello world!"}
      changeset = Post.changeset(%Post{}, attrs)
      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates content_text minimum length", %{author: author} do
      attrs = %{content_text: "", user_id: author.id}
      changeset = Post.changeset(%Post{}, attrs)
      refute changeset.valid?
      assert %{content_text: [_]} = errors_on(changeset)
    end

    test "validates content_text maximum length", %{author: author} do
      long_text = String.duplicate("a", 10_001)
      attrs = %{content_text: long_text, user_id: author.id}
      changeset = Post.changeset(%Post{}, attrs)
      refute changeset.valid?
      assert %{content_text: [_]} = errors_on(changeset)
    end

    test "validates content_type inclusion", %{author: author} do
      attrs = %{content_text: "Hello", user_id: author.id, content_type: "invalid"}
      changeset = Post.changeset(%Post{}, attrs)
      refute changeset.valid?
      assert %{content_type: ["is invalid"]} = errors_on(changeset)
    end

    test "accepts all valid content types", %{author: author} do
      for content_type <- ~w(text image video carousel link) do
        attrs = %{content_text: "Hello", user_id: author.id, content_type: content_type}
        changeset = Post.changeset(%Post{}, attrs)
        assert changeset.valid?, "Expected content_type #{content_type} to be valid"
      end
    end

    test "validates status inclusion", %{author: author} do
      attrs = %{content_text: "Hello", user_id: author.id, status: "invalid"}
      changeset = Post.changeset(%Post{}, attrs)
      refute changeset.valid?
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end

    test "accepts all valid statuses", %{author: author} do
      for status <- ~w(draft scheduled publishing published failed) do
        attrs = %{content_text: "Hello", user_id: author.id, status: status}
        changeset = Post.changeset(%Post{}, attrs)
        assert changeset.valid?, "Expected status #{status} to be valid"
      end
    end

    test "valid with all optional fields", %{author: author} do
      attrs = %{
        content_text: "Check out our latest blog post!",
        content_type: "link",
        media_urls: ["https://example.com/image1.jpg", "https://example.com/image2.jpg"],
        link_url: "https://example.com/blog/post",
        link_preview_data: %{"title" => "Blog Post", "description" => "A great post"},
        status: "draft",
        scheduled_for: DateTime.utc_now() |> DateTime.add(3600, :second),
        ai_generated: true,
        ai_prompt: "Write a post about our new feature",
        metadata: %{"campaign" => "launch"},
        user_id: author.id
      }

      changeset = Post.changeset(%Post{}, attrs)
      assert changeset.valid?
    end

    test "defaults content_type to text", %{author: author} do
      attrs = %{content_text: "Hello", user_id: author.id}
      changeset = Post.changeset(%Post{}, attrs)
      post = Ecto.Changeset.apply_changes(changeset)
      assert post.content_type == "text"
    end

    test "defaults status to draft", %{author: author} do
      attrs = %{content_text: "Hello", user_id: author.id}
      changeset = Post.changeset(%Post{}, attrs)
      post = Ecto.Changeset.apply_changes(changeset)
      assert post.status == "draft"
    end

    test "defaults to empty arrays and maps", %{author: author} do
      attrs = %{content_text: "Hello", user_id: author.id}
      changeset = Post.changeset(%Post{}, attrs)
      post = Ecto.Changeset.apply_changes(changeset)
      assert post.media_urls == []
      assert post.link_preview_data == %{}
      assert post.metadata == %{}
    end

    test "defaults ai_generated to false", %{author: author} do
      attrs = %{content_text: "Hello", user_id: author.id}
      changeset = Post.changeset(%Post{}, attrs)
      post = Ecto.Changeset.apply_changes(changeset)
      assert post.ai_generated == false
    end
  end

  describe "schedule_changeset/2" do
    test "sets status to scheduled with future time" do
      post = %Post{status: "draft"}
      future = DateTime.utc_now() |> DateTime.add(3600, :second)

      changeset = Post.schedule_changeset(post, future)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :status) == "scheduled"
      assert Ecto.Changeset.get_change(changeset, :scheduled_for) == future
    end

    test "rejects past scheduled_for time" do
      post = %Post{status: "draft"}
      past = DateTime.utc_now() |> DateTime.add(-3600, :second)

      changeset = Post.schedule_changeset(post, past)

      refute changeset.valid?
      assert %{scheduled_for: ["must be in the future"]} = errors_on(changeset)
    end

    test "rejects nil scheduled_for" do
      post = %Post{status: "draft"}

      changeset = Post.schedule_changeset(post, nil)

      refute changeset.valid?
      assert %{scheduled_for: ["must be set for scheduled posts"]} = errors_on(changeset)
    end
  end

  describe "publish_changeset/1" do
    test "sets status to published with timestamp" do
      post = %Post{status: "scheduled"}

      changeset = Post.publish_changeset(post)

      assert Ecto.Changeset.get_change(changeset, :status) == "published"
      assert Ecto.Changeset.get_change(changeset, :published_at)
    end
  end

  describe "content_types/0" do
    test "returns valid content types" do
      assert Post.content_types() == ~w(text image video carousel link)
    end
  end

  describe "status_values/0" do
    test "returns valid status values" do
      assert Post.status_values() == ~w(draft scheduled publishing published failed)
    end
  end
end
