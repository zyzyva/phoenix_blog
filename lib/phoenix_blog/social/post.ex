defmodule PhoenixBlog.Social.Post do
  @moduledoc """
  Schema for social media posts.

  Posts can be scheduled for future publishing or published immediately.
  They can optionally be derived from blog posts.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @content_types ~w(text image video carousel link)
  @status_values ~w(draft scheduled publishing published failed)

  schema "social_posts" do
    field :content_text, :string
    field :content_type, :string, default: "text"
    field :media_urls, {:array, :string}, default: []
    field :link_url, :string
    field :link_preview_data, :map, default: %{}
    field :status, :string, default: "draft"
    field :scheduled_for, :utc_datetime
    field :published_at, :utc_datetime
    field :ai_generated, :boolean, default: false
    field :ai_prompt, :string
    field :metadata, :map, default: %{}

    belongs_to :user, PhoenixBlog.Blog.Author, foreign_key: :user_id
    belongs_to :blog_post, PhoenixBlog.Blog.Post, foreign_key: :blog_post_id
    has_many :post_platforms, PhoenixBlog.Social.PostPlatform, foreign_key: :social_post_id

    timestamps(type: :utc_datetime)
  end

  def changeset(post, attrs) do
    post
    |> cast(attrs, [
      :content_text,
      :content_type,
      :media_urls,
      :link_url,
      :link_preview_data,
      :status,
      :scheduled_for,
      :ai_generated,
      :ai_prompt,
      :metadata,
      :user_id,
      :blog_post_id
    ])
    |> validate_required([:content_text, :user_id])
    |> validate_inclusion(:content_type, @content_types)
    |> validate_inclusion(:status, @status_values)
    |> validate_length(:content_text, min: 1, max: 10_000)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:blog_post_id)
  end

  def schedule_changeset(post, scheduled_for) do
    post
    |> change(%{scheduled_for: scheduled_for, status: "scheduled"})
    |> validate_scheduled_for_future()
  end

  def publish_changeset(post) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    post
    |> change(%{status: "published", published_at: now})
  end

  def content_types, do: @content_types
  def status_values, do: @status_values

  defp validate_scheduled_for_future(changeset) do
    case get_field(changeset, :scheduled_for) do
      nil ->
        add_error(changeset, :scheduled_for, "must be set for scheduled posts")

      scheduled_for ->
        if DateTime.compare(scheduled_for, DateTime.utc_now()) == :gt do
          changeset
        else
          add_error(changeset, :scheduled_for, "must be in the future")
        end
    end
  end
end
