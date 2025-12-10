defmodule PhoenixBlog.Social.AnalyticsRecord do
  @moduledoc """
  Schema for social media analytics data.

  Stores metrics fetched from platforms for each published post.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "social_analytics" do
    field :fetched_at, :utc_datetime
    field :impressions, :integer
    field :engagements, :integer
    field :likes, :integer
    field :comments, :integer
    field :shares, :integer
    field :clicks, :integer
    field :reach, :integer
    field :video_views, :integer
    field :raw_data, :map, default: %{}

    belongs_to :post_platform, PhoenixBlog.Social.PostPlatform,
      foreign_key: :social_post_platform_id

    timestamps(type: :utc_datetime)
  end

  def changeset(record, attrs) do
    record
    |> cast(attrs, [
      :fetched_at,
      :impressions,
      :engagements,
      :likes,
      :comments,
      :shares,
      :clicks,
      :reach,
      :video_views,
      :raw_data,
      :social_post_platform_id
    ])
    |> validate_required([:fetched_at, :social_post_platform_id])
    |> foreign_key_constraint(:social_post_platform_id)
  end
end
