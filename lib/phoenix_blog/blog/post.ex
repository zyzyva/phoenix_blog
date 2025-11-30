defmodule PhoenixBlog.Blog.Post do
  @moduledoc """
  Schema for blog posts.

  Blog posts support markdown content that is rendered to HTML on save.
  Posts can be in draft or published status.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @status_values ~w(draft published)

  schema "blog_posts" do
    field :title, :string
    field :slug, :string
    field :content_markdown, :string
    field :content_html, :string
    field :excerpt, :string
    field :status, :string, default: "draft"
    field :featured_image_url, :string
    field :featured_image_alt, :string
    field :meta_title, :string
    field :meta_description, :string
    field :canonical_url, :string
    field :published_at, :utc_datetime

    belongs_to :user, PhoenixBlog.Blog.Author, foreign_key: :user_id
    has_many :images, PhoenixBlog.Blog.Image, foreign_key: :blog_post_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for content operations (creating and editing posts).
  """
  def changeset(post, attrs) do
    post
    |> cast(attrs, [
      :title,
      :content_markdown,
      :excerpt,
      :featured_image_url,
      :featured_image_alt,
      :meta_title,
      :meta_description,
      :canonical_url,
      :user_id
    ])
    |> validate_required([:title, :content_markdown, :user_id])
    |> validate_length(:title, min: 1, max: 200)
    |> validate_length(:excerpt, max: 500)
    |> validate_length(:featured_image_alt, max: 125)
    |> validate_length(:meta_title, max: 60)
    |> validate_length(:meta_description, max: 160)
    |> generate_slug()
    |> render_markdown()
    |> unique_constraint(:slug)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Changeset for admin/status operations (publishing, unpublishing).
  """
  def admin_changeset(post, attrs) do
    post
    |> cast(attrs, [:status, :published_at])
    |> validate_inclusion(:status, @status_values)
    |> maybe_set_published_at()
  end

  @doc """
  Returns the list of valid status values.
  """
  def status_values, do: @status_values

  # Generate slug from title if not already set or if title changed
  defp generate_slug(changeset) do
    case {get_field(changeset, :slug), get_change(changeset, :title)} do
      {nil, title} when is_binary(title) ->
        put_change(changeset, :slug, slugify(title))

      {_existing, nil} ->
        changeset

      {_existing, new_title} when is_binary(new_title) ->
        # Only regenerate slug if it's a new record
        if get_field(changeset, :id) do
          changeset
        else
          put_change(changeset, :slug, slugify(new_title))
        end
    end
  end

  defp slugify(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/u, "")
    |> String.replace(~r/[\s_]+/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
    |> String.slice(0, 200)
  end

  # Render markdown to HTML using MDEx
  defp render_markdown(changeset) do
    case get_change(changeset, :content_markdown) do
      nil ->
        changeset

      markdown when is_binary(markdown) ->
        case MDEx.to_html(markdown) do
          {:ok, html} ->
            put_change(changeset, :content_html, html)

          {:error, _reason} ->
            add_error(changeset, :content_markdown, "could not be rendered")
        end
    end
  end

  # Set published_at when status changes to published
  defp maybe_set_published_at(changeset) do
    case get_change(changeset, :status) do
      "published" ->
        if get_field(changeset, :published_at) do
          changeset
        else
          put_change(changeset, :published_at, DateTime.utc_now() |> DateTime.truncate(:second))
        end

      _ ->
        changeset
    end
  end
end
