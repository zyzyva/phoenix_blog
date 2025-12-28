defmodule PhoenixBlog.Blog.PostSchemaTest do
  use PhoenixBlog.DataCase, async: true

  alias PhoenixBlog.Blog.Post
  import PhoenixBlog.Fixtures

  describe "changeset/2" do
    setup do
      %{author: author_fixture()}
    end

    test "valid with required fields", %{author: author} do
      attrs = %{title: "My Post", content_markdown: "Hello world", user_id: author.id}
      changeset = Post.changeset(%Post{}, attrs)
      assert changeset.valid?
    end

    test "invalid without title", %{author: author} do
      attrs = %{content_markdown: "Hello world", user_id: author.id}
      changeset = Post.changeset(%Post{}, attrs)
      refute changeset.valid?
      assert %{title: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without content_markdown", %{author: author} do
      attrs = %{title: "My Post", user_id: author.id}
      changeset = Post.changeset(%Post{}, attrs)
      refute changeset.valid?
      assert %{content_markdown: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without user_id" do
      attrs = %{title: "My Post", content_markdown: "Hello world"}
      changeset = Post.changeset(%Post{}, attrs)
      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates title minimum length", %{author: author} do
      attrs = %{title: "", content_markdown: "Hello", user_id: author.id}
      changeset = Post.changeset(%Post{}, attrs)
      refute changeset.valid?
      assert %{title: [_]} = errors_on(changeset)
    end

    test "validates title maximum length", %{author: author} do
      long_title = String.duplicate("a", 201)
      attrs = %{title: long_title, content_markdown: "Hello", user_id: author.id}
      changeset = Post.changeset(%Post{}, attrs)
      refute changeset.valid?
      assert %{title: [_]} = errors_on(changeset)
    end

    test "validates excerpt maximum length", %{author: author} do
      long_excerpt = String.duplicate("a", 501)
      attrs = %{title: "Post", content_markdown: "Hello", user_id: author.id, excerpt: long_excerpt}
      changeset = Post.changeset(%Post{}, attrs)
      refute changeset.valid?
      assert %{excerpt: [_]} = errors_on(changeset)
    end

    test "validates meta_title maximum length", %{author: author} do
      long_meta = String.duplicate("a", 61)
      attrs = %{title: "Post", content_markdown: "Hello", user_id: author.id, meta_title: long_meta}
      changeset = Post.changeset(%Post{}, attrs)
      refute changeset.valid?
      assert %{meta_title: [_]} = errors_on(changeset)
    end

    test "validates meta_description maximum length", %{author: author} do
      long_meta = String.duplicate("a", 161)
      attrs = %{title: "Post", content_markdown: "Hello", user_id: author.id, meta_description: long_meta}
      changeset = Post.changeset(%Post{}, attrs)
      refute changeset.valid?
      assert %{meta_description: [_]} = errors_on(changeset)
    end

    test "generates slug from title", %{author: author} do
      attrs = %{title: "My Awesome Blog Post", content_markdown: "Hello", user_id: author.id}
      changeset = Post.changeset(%Post{}, attrs)
      assert Ecto.Changeset.get_change(changeset, :slug) == "my-awesome-blog-post"
    end

    test "renders markdown to html", %{author: author} do
      attrs = %{title: "Post", content_markdown: "# Hello\n\nWorld", user_id: author.id}
      changeset = Post.changeset(%Post{}, attrs)
      html = Ecto.Changeset.get_change(changeset, :content_html)
      assert html =~ "<h1>"
      assert html =~ "Hello"
    end

    test "defaults status to draft", %{author: author} do
      attrs = %{title: "Post", content_markdown: "Hello", user_id: author.id}
      changeset = Post.changeset(%Post{}, attrs)
      post = Ecto.Changeset.apply_changes(changeset)
      assert post.status == "draft"
    end
  end

  describe "admin_changeset/2" do
    test "validates status inclusion" do
      post = %Post{status: "draft"}
      changeset = Post.admin_changeset(post, %{status: "invalid"})
      refute changeset.valid?
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end

    test "accepts valid statuses" do
      for status <- ~w(draft published) do
        post = %Post{status: "draft"}
        changeset = Post.admin_changeset(post, %{status: status})
        assert changeset.valid?, "Expected status #{status} to be valid"
      end
    end

    test "sets published_at when publishing" do
      post = %Post{status: "draft", published_at: nil}
      changeset = Post.admin_changeset(post, %{status: "published"})
      assert Ecto.Changeset.get_change(changeset, :published_at)
    end

    test "preserves existing published_at when already set" do
      existing_time = ~U[2024-01-01 12:00:00Z]
      post = %Post{status: "draft", published_at: existing_time}
      changeset = Post.admin_changeset(post, %{status: "published"})
      refute Ecto.Changeset.get_change(changeset, :published_at)
    end
  end

  describe "status_values/0" do
    test "returns valid status values" do
      assert Post.status_values() == ~w(draft published)
    end
  end
end
