defmodule PhoenixBlog.Repo.Migrations.CreatePosts do
  use Ecto.Migration

  def change do
    create table(:posts) do
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

      add :user_id, references(:authors, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:posts, [:slug])
    create index(:posts, [:status])
    create index(:posts, [:published_at])
    create index(:posts, [:user_id])
  end
end
