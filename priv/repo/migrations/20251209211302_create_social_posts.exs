defmodule PhoenixBlog.Repo.Migrations.CreateSocialPosts do
  use Ecto.Migration

  def change do
    create table(:social_posts) do
      add :content_text, :text, null: false
      add :content_type, :string, default: "text", null: false
      add :media_urls, {:array, :string}, default: []
      add :link_url, :string
      add :link_preview_data, :map, default: %{}
      add :status, :string, default: "draft", null: false
      add :scheduled_for, :utc_datetime
      add :published_at, :utc_datetime
      add :ai_generated, :boolean, default: false
      add :ai_prompt, :text

      add :user_id, references(:authors, on_delete: :delete_all), null: false
      add :blog_post_id, references(:posts, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:social_posts, [:user_id])
    create index(:social_posts, [:status])
    create index(:social_posts, [:scheduled_for])
    create index(:social_posts, [:blog_post_id])
  end
end
