defmodule PhoenixBlog.Social.PostPlatform do
  @moduledoc """
  Schema for the join between social posts and target platforms.

  Tracks the publishing status and results for each platform a post is sent to.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @status_values ~w(pending publishing published failed)

  schema "social_post_platforms" do
    field :platform_post_id, :string
    field :platform_url, :string
    field :status, :string, default: "pending"
    field :error_message, :string
    field :published_at, :utc_datetime
    field :platform_specific_content, :map, default: %{}

    belongs_to :social_post, PhoenixBlog.Social.Post, foreign_key: :social_post_id
    belongs_to :social_account, PhoenixBlog.Social.Account, foreign_key: :social_account_id
    has_many :analytics, PhoenixBlog.Social.AnalyticsRecord, foreign_key: :social_post_platform_id

    timestamps(type: :utc_datetime)
  end

  def changeset(post_platform, attrs) do
    post_platform
    |> cast(attrs, [
      :platform_specific_content,
      :social_post_id,
      :social_account_id
    ])
    |> validate_required([:social_post_id, :social_account_id])
    |> unique_constraint([:social_post_id, :social_account_id])
    |> foreign_key_constraint(:social_post_id)
    |> foreign_key_constraint(:social_account_id)
  end

  def publish_changeset(post_platform, attrs) do
    post_platform
    |> cast(attrs, [:platform_post_id, :platform_url, :status, :error_message, :published_at])
    |> validate_inclusion(:status, @status_values)
  end

  def status_values, do: @status_values
end
