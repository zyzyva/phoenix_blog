defmodule PhoenixBlog.Repo.Migrations.CreateSocialAnalytics do
  use Ecto.Migration

  def change do
    create table(:social_analytics) do
      add :fetched_at, :utc_datetime, null: false
      add :impressions, :integer
      add :engagements, :integer
      add :likes, :integer
      add :comments, :integer
      add :shares, :integer
      add :clicks, :integer
      add :reach, :integer
      add :video_views, :integer
      add :raw_data, :map, default: %{}

      add :social_post_platform_id, references(:social_post_platforms, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime)
    end

    create index(:social_analytics, [:social_post_platform_id])
    create index(:social_analytics, [:fetched_at])
  end
end
