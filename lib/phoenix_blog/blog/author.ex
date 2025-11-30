defmodule PhoenixBlog.Blog.Author do
  @moduledoc """
  Schema for blog authors.

  This is a lightweight schema that references users from the host application.
  The actual user management is handled by the host app - this just stores
  the minimum needed for blog authorship.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "blog_authors" do
    field :name, :string
    field :email, :string
    field :avatar_url, :string
    field :bio, :string
    field :external_id, :string

    has_many :posts, PhoenixBlog.Blog.Post, foreign_key: :user_id
    has_many :images, PhoenixBlog.Blog.Image, foreign_key: :user_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating/updating authors.
  """
  def changeset(author, attrs) do
    author
    |> cast(attrs, [:name, :email, :avatar_url, :bio, :external_id])
    |> validate_required([:name, :email])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:bio, max: 500)
    |> unique_constraint(:email)
    |> unique_constraint(:external_id)
  end
end
