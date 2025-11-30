defmodule PhoenixBlog.Blog do
  @moduledoc """
  The Blog context for managing blog posts, images, and authors.
  """

  import Ecto.Query, warn: false
  alias PhoenixBlog.Repo
  alias PhoenixBlog.Blog.{Post, Image, Author}

  # ============================================================================
  # Blog Post Functions
  # ============================================================================

  @doc """
  Lists published posts for public display with pagination.
  """
  def list_published_posts(opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    offset = Keyword.get(opts, :offset, 0)

    Post
    |> where([p], p.status == "published")
    |> order_by([p], desc: p.published_at)
    |> limit(^limit)
    |> offset(^offset)
    |> preload(:user)
    |> Repo.all()
  end

  @doc """
  Lists all posts for admin with optional status filter.
  """
  def list_all_posts(opts \\ []) do
    status = Keyword.get(opts, :status)

    Post
    |> maybe_filter_by_status(status)
    |> order_by([p], desc: p.inserted_at)
    |> preload(:user)
    |> Repo.all()
  end

  @doc """
  Gets a single post by ID with preloads.
  """
  def get_post!(id) do
    Post
    |> Repo.get!(id)
    |> Repo.preload([:user, :images])
  end

  @doc """
  Gets a post by slug (for public display, any status).
  """
  def get_post_by_slug!(slug) do
    Post
    |> Repo.get_by!(slug: slug)
    |> Repo.preload([:user, :images])
  end

  @doc """
  Gets a published post by slug (for public display).
  """
  def get_published_post_by_slug!(slug) do
    Post
    |> where([p], p.slug == ^slug and p.status == "published")
    |> Repo.one!()
    |> Repo.preload([:user, :images])
  end

  @doc """
  Gets a published post by slug, returns nil if not found.
  """
  def get_published_post_by_slug(slug) do
    Post
    |> where([p], p.slug == ^slug and p.status == "published")
    |> Repo.one()
    |> case do
      nil -> nil
      post -> Repo.preload(post, [:user, :images])
    end
  end

  @doc """
  Creates a new blog post for an author.
  """
  def create_post(author_id, attrs) when is_integer(author_id) do
    %Post{}
    |> Post.changeset(Map.put(attrs, "user_id", author_id))
    |> Repo.insert()
  end

  def create_post(%Author{id: author_id}, attrs), do: create_post(author_id, attrs)

  @doc """
  Updates a blog post's content.
  """
  def update_post(%Post{} = post, attrs) do
    post
    |> Post.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Publishes a blog post.
  """
  def publish_post(%Post{} = post) do
    post
    |> Post.admin_changeset(%{status: "published"})
    |> Repo.update()
  end

  @doc """
  Unpublishes a blog post (returns to draft).
  """
  def unpublish_post(%Post{} = post) do
    post
    |> Post.admin_changeset(%{status: "draft", published_at: nil})
    |> Repo.update()
  end

  @doc """
  Deletes a blog post.
  """
  def delete_post(%Post{} = post) do
    Repo.delete(post)
  end

  @doc """
  Returns a changeset for tracking post changes.
  """
  def change_post(%Post{} = post, attrs \\ %{}) do
    Post.changeset(post, attrs)
  end

  @doc """
  Counts posts by status.
  """
  def count_by_status do
    Post
    |> group_by([p], p.status)
    |> select([p], {p.status, count(p.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Counts total published posts.
  """
  def count_published_posts do
    Post
    |> where([p], p.status == "published")
    |> Repo.aggregate(:count)
  end

  # ============================================================================
  # Blog Image Functions
  # ============================================================================

  @doc """
  Creates a new blog image record.
  """
  def create_image(author_id, attrs) when is_integer(author_id) do
    %Image{}
    |> Image.changeset(Map.put(attrs, "user_id", author_id))
    |> Repo.insert()
  end

  def create_image(%Author{id: author_id}, attrs), do: create_image(author_id, attrs)

  @doc """
  Lists images for a specific post.
  """
  def list_images_for_post(post_id) do
    Image
    |> where([i], i.blog_post_id == ^post_id)
    |> order_by([i], desc: i.inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists orphan images (not associated with any post) for an author.
  """
  def list_orphan_images(author_id) when is_integer(author_id) do
    Image
    |> where([i], is_nil(i.blog_post_id) and i.user_id == ^author_id)
    |> order_by([i], desc: i.inserted_at)
    |> Repo.all()
  end

  def list_orphan_images(%Author{id: author_id}), do: list_orphan_images(author_id)

  @doc """
  Gets a single image by ID.
  """
  def get_image!(id), do: Repo.get!(Image, id)

  @doc """
  Associates an image with a post.
  """
  def associate_image_with_post(%Image{} = image, post_id) do
    image
    |> Image.associate_changeset(%{blog_post_id: post_id})
    |> Repo.update()
  end

  @doc """
  Deletes an image record.
  Note: The caller is responsible for deleting from storage.
  """
  def delete_image(%Image{} = image) do
    Repo.delete(image)
  end

  # ============================================================================
  # Author Functions
  # ============================================================================

  @doc """
  Gets an author by ID.
  """
  def get_author!(id), do: Repo.get!(Author, id)

  @doc """
  Gets an author by email.
  """
  def get_author_by_email(email), do: Repo.get_by(Author, email: email)

  @doc """
  Gets an author by external ID (user ID from host app).
  """
  def get_author_by_external_id(external_id), do: Repo.get_by(Author, external_id: external_id)

  @doc """
  Gets or creates an author from host app user data.
  """
  def get_or_create_author(attrs) do
    case get_author_by_external_id(attrs["external_id"] || attrs[:external_id]) do
      nil ->
        %Author{}
        |> Author.changeset(attrs)
        |> Repo.insert()

      author ->
        {:ok, author}
    end
  end

  @doc """
  Lists all authors.
  """
  def list_authors do
    Author
    |> order_by([a], asc: a.name)
    |> Repo.all()
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp maybe_filter_by_status(query, nil), do: query
  defp maybe_filter_by_status(query, status), do: where(query, [p], p.status == ^status)
end
