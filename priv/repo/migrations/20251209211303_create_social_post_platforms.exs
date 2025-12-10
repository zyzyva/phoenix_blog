defmodule PhoenixBlog.Repo.Migrations.CreateSocialPostPlatforms do
  use Ecto.Migration

  def change do
    create table(:social_post_platforms) do
      add :platform_post_id, :string
      add :platform_url, :string
      add :status, :string, default: "pending", null: false
      add :error_message, :text
      add :published_at, :utc_datetime
      add :platform_specific_content, :map, default: %{}

      add :social_post_id, references(:social_posts, on_delete: :delete_all), null: false
      add :social_account_id, references(:social_accounts, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:social_post_platforms, [:social_post_id])
    create index(:social_post_platforms, [:social_account_id])
    create index(:social_post_platforms, [:status])
    create unique_index(:social_post_platforms, [:social_post_id, :social_account_id])
  end
end
