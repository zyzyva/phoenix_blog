defmodule PhoenixBlog.Repo.Migrations.CreateBlogAuthors do
  use Ecto.Migration

  def change do
    create table(:blog_authors) do
      add :name, :string, null: false
      add :email, :string, null: false
      add :avatar_url, :string
      add :bio, :text
      add :external_id, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:blog_authors, [:email])
    create unique_index(:blog_authors, [:external_id])
  end
end
