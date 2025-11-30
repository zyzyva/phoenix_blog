defmodule PhoenixBlog.Blog.Image do
  @moduledoc """
  Schema for blog images stored in cloud storage (R2/S3).

  Images can be associated with a blog post or exist as orphans
  (uploaded but not yet linked to a post).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :id

  schema "images" do
    field :filename, :string
    field :storage_key, :string
    field :url, :string
    field :content_type, :string
    field :file_size, :integer
    field :alt_text, :string

    belongs_to :post, PhoenixBlog.Blog.Post
    belongs_to :user, PhoenixBlog.Blog.Author, foreign_key: :user_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating new blog images.
  """
  def changeset(image, attrs) do
    image
    |> cast(attrs, [
      :filename,
      :storage_key,
      :url,
      :content_type,
      :file_size,
      :alt_text,
      :post_id,
      :user_id
    ])
    |> validate_required([:filename, :storage_key, :url, :content_type, :user_id])
    |> validate_length(:alt_text, max: 125)
    |> foreign_key_constraint(:post_id)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Changeset for associating an image with a blog post.
  """
  def associate_changeset(image, attrs) do
    image
    |> cast(attrs, [:post_id, :alt_text])
    |> validate_length(:alt_text, max: 125)
    |> foreign_key_constraint(:post_id)
  end
end
