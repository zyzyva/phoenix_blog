defmodule PhoenixBlog.BlogTest do
  use PhoenixBlog.DataCase, async: true

  alias PhoenixBlog.Blog

  describe "authors" do
    @valid_author_attrs %{
      name: "John Doe",
      email: "john@example.com",
      bio: "A test author",
      external_id: "user_123"
    }

    test "get_or_create_author/1 creates a new author" do
      assert {:ok, author} = Blog.get_or_create_author(@valid_author_attrs)
      assert author.name == "John Doe"
      assert author.email == "john@example.com"
      assert author.external_id == "user_123"
    end

    test "get_or_create_author/1 returns existing author" do
      {:ok, original} = Blog.get_or_create_author(@valid_author_attrs)
      {:ok, found} = Blog.get_or_create_author(@valid_author_attrs)
      assert original.id == found.id
    end

    test "get_author!/1 returns the author" do
      {:ok, author} = Blog.get_or_create_author(@valid_author_attrs)
      assert Blog.get_author!(author.id).id == author.id
    end

    test "get_author_by_email/1 returns the author" do
      {:ok, author} = Blog.get_or_create_author(@valid_author_attrs)
      assert Blog.get_author_by_email("john@example.com").id == author.id
    end

    test "get_author_by_external_id/1 returns the author" do
      {:ok, author} = Blog.get_or_create_author(@valid_author_attrs)
      assert Blog.get_author_by_external_id("user_123").id == author.id
    end

    test "list_authors/0 returns all authors" do
      {:ok, author} = Blog.get_or_create_author(@valid_author_attrs)
      assert Blog.list_authors() == [author]
    end
  end

  describe "posts" do
    setup do
      {:ok, author} = Blog.get_or_create_author(%{name: "Test Author", email: "test@example.com"})
      %{author: author}
    end

    @valid_post_attrs %{
      "title" => "Test Post Title",
      "content_markdown" => "# Hello\n\nThis is test content."
    }

    test "create_post/2 creates a post with valid data", %{author: author} do
      assert {:ok, post} = Blog.create_post(author, @valid_post_attrs)
      assert post.title == "Test Post Title"
      assert post.slug == "test-post-title"
      assert post.status == "draft"
      assert post.content_html =~ "<h1>Hello</h1>"
    end

    test "create_post/2 with author_id creates a post", %{author: author} do
      assert {:ok, post} = Blog.create_post(author.id, @valid_post_attrs)
      assert post.title == "Test Post Title"
    end

    test "create_post/2 fails without title", %{author: author} do
      attrs = Map.delete(@valid_post_attrs, "title")
      assert {:error, changeset} = Blog.create_post(author, attrs)
      assert %{title: ["can't be blank"]} = errors_on(changeset)
    end

    test "create_post/2 fails without content", %{author: author} do
      attrs = Map.delete(@valid_post_attrs, "content_markdown")
      assert {:error, changeset} = Blog.create_post(author, attrs)
      assert %{content_markdown: ["can't be blank"]} = errors_on(changeset)
    end

    test "get_post!/1 returns the post with preloads", %{author: author} do
      {:ok, post} = Blog.create_post(author, @valid_post_attrs)
      fetched = Blog.get_post!(post.id)
      assert fetched.id == post.id
      assert fetched.user != nil
    end

    test "get_post_by_slug!/1 returns the post", %{author: author} do
      {:ok, post} = Blog.create_post(author, @valid_post_attrs)
      fetched = Blog.get_post_by_slug!(post.slug)
      assert fetched.id == post.id
    end

    test "update_post/2 updates the post", %{author: author} do
      {:ok, post} = Blog.create_post(author, @valid_post_attrs)
      assert {:ok, updated} = Blog.update_post(post, %{"title" => "Updated Title"})
      assert updated.title == "Updated Title"
      # Slug should not change on update
      assert updated.slug == "test-post-title"
    end

    test "publish_post/1 publishes a draft post", %{author: author} do
      {:ok, post} = Blog.create_post(author, @valid_post_attrs)
      assert post.status == "draft"
      assert post.published_at == nil

      assert {:ok, published} = Blog.publish_post(post)
      assert published.status == "published"
      assert published.published_at != nil
    end

    test "unpublish_post/1 returns post to draft", %{author: author} do
      {:ok, post} = Blog.create_post(author, @valid_post_attrs)
      {:ok, published} = Blog.publish_post(post)
      assert {:ok, unpublished} = Blog.unpublish_post(published)
      assert unpublished.status == "draft"
      assert unpublished.published_at == nil
    end

    test "delete_post/1 removes the post", %{author: author} do
      {:ok, post} = Blog.create_post(author, @valid_post_attrs)
      assert {:ok, _} = Blog.delete_post(post)
      assert_raise Ecto.NoResultsError, fn -> Blog.get_post!(post.id) end
    end

    test "list_published_posts/0 returns only published posts", %{author: author} do
      {:ok, _draft} = Blog.create_post(author, @valid_post_attrs)
      {:ok, post2} = Blog.create_post(author, %{@valid_post_attrs | "title" => "Second Post"})
      {:ok, published} = Blog.publish_post(post2)

      posts = Blog.list_published_posts()
      assert length(posts) == 1
      assert hd(posts).id == published.id
    end

    test "list_all_posts/0 returns all posts", %{author: author} do
      {:ok, _draft} = Blog.create_post(author, @valid_post_attrs)
      {:ok, post2} = Blog.create_post(author, %{@valid_post_attrs | "title" => "Second Post"})
      {:ok, _published} = Blog.publish_post(post2)

      posts = Blog.list_all_posts()
      assert length(posts) == 2
    end

    test "list_all_posts/1 filters by status", %{author: author} do
      {:ok, _draft} = Blog.create_post(author, @valid_post_attrs)
      {:ok, post2} = Blog.create_post(author, %{@valid_post_attrs | "title" => "Second Post"})
      {:ok, _published} = Blog.publish_post(post2)

      drafts = Blog.list_all_posts(status: "draft")
      assert length(drafts) == 1

      published = Blog.list_all_posts(status: "published")
      assert length(published) == 1
    end

    test "count_by_status/0 returns status counts", %{author: author} do
      {:ok, _draft} = Blog.create_post(author, @valid_post_attrs)
      {:ok, post2} = Blog.create_post(author, %{@valid_post_attrs | "title" => "Second Post"})
      {:ok, _published} = Blog.publish_post(post2)

      counts = Blog.count_by_status()
      assert counts["draft"] == 1
      assert counts["published"] == 1
    end

    test "count_published_posts/0 returns published count", %{author: author} do
      {:ok, _draft} = Blog.create_post(author, @valid_post_attrs)
      {:ok, post2} = Blog.create_post(author, %{@valid_post_attrs | "title" => "Second Post"})
      {:ok, _published} = Blog.publish_post(post2)

      assert Blog.count_published_posts() == 1
    end

    test "change_post/2 returns a changeset", %{author: author} do
      {:ok, post} = Blog.create_post(author, @valid_post_attrs)
      changeset = Blog.change_post(post, %{title: "New Title"})
      assert %Ecto.Changeset{} = changeset
    end
  end

  describe "images" do
    setup do
      {:ok, author} = Blog.get_or_create_author(%{name: "Test Author", email: "test@example.com"})

      {:ok, post} =
        Blog.create_post(author, %{"title" => "Test", "content_markdown" => "Content"})

      %{author: author, post: post}
    end

    @valid_image_attrs %{
      "filename" => "test.jpg",
      "storage_key" => "blog/images/2024/01/abc12345-test.jpg",
      "url" => "https://cdn.example.com/blog/images/2024/01/abc12345-test.jpg",
      "content_type" => "image/jpeg"
    }

    test "create_image/2 creates an image", %{author: author} do
      assert {:ok, image} = Blog.create_image(author, @valid_image_attrs)
      assert image.filename == "test.jpg"
      assert image.post_id == nil
    end

    test "get_image!/1 returns the image", %{author: author} do
      {:ok, image} = Blog.create_image(author, @valid_image_attrs)
      fetched = Blog.get_image!(image.id)
      assert fetched.id == image.id
    end

    test "list_images_for_post/1 returns post images", %{author: author, post: post} do
      {:ok, image} = Blog.create_image(author, @valid_image_attrs)
      {:ok, _} = Blog.associate_image_with_post(image, post.id)

      images = Blog.list_images_for_post(post.id)
      assert length(images) == 1
    end

    test "list_orphan_images/1 returns unassociated images", %{author: author, post: post} do
      {:ok, orphan} = Blog.create_image(author, @valid_image_attrs)

      {:ok, attached} =
        Blog.create_image(author, %{@valid_image_attrs | "filename" => "attached.jpg"})

      {:ok, _} = Blog.associate_image_with_post(attached, post.id)

      orphans = Blog.list_orphan_images(author)
      assert length(orphans) == 1
      assert hd(orphans).id == orphan.id
    end

    test "associate_image_with_post/2 links image to post", %{author: author, post: post} do
      {:ok, image} = Blog.create_image(author, @valid_image_attrs)
      assert image.post_id == nil

      {:ok, updated} = Blog.associate_image_with_post(image, post.id)
      assert updated.post_id == post.id
    end

    test "delete_image/1 removes the image", %{author: author} do
      {:ok, image} = Blog.create_image(author, @valid_image_attrs)
      assert {:ok, _} = Blog.delete_image(image)
      assert_raise Ecto.NoResultsError, fn -> Blog.get_image!(image.id) end
    end
  end
end
