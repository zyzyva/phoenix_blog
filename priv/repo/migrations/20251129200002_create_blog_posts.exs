defmodule PhoenixBlog.Repo.Migrations.CreateBlogPosts do
  use Ecto.Migration

  def change do
    create table(:blog_posts) do
      add :title, :string, null: false
      add :slug, :string, null: false
      add :content_markdown, :text, null: false
      add :content_html, :text
      add :excerpt, :text
      add :status, :string, default: "draft", null: false
      add :featured_image_url, :string
      add :featured_image_alt, :string
      add :meta_title, :string
      add :meta_description, :string
      add :canonical_url, :string
      add :published_at, :utc_datetime

      add :user_id, references(:blog_authors, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:blog_posts, [:slug])
    create index(:blog_posts, [:status])
    create index(:blog_posts, [:published_at])
    create index(:blog_posts, [:user_id])
  end
end
