defmodule PhoenixBlog.Repo.Migrations.CreateBlogImages do
  use Ecto.Migration

  def change do
    create table(:blog_images, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :filename, :string, null: false
      add :storage_key, :string, null: false
      add :url, :string, null: false
      add :content_type, :string, null: false
      add :file_size, :integer
      add :alt_text, :string

      add :blog_post_id, references(:blog_posts, on_delete: :nilify_all)
      add :user_id, references(:blog_authors, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:blog_images, [:blog_post_id])
    create index(:blog_images, [:user_id])
    create index(:blog_images, [:storage_key])
  end
end
