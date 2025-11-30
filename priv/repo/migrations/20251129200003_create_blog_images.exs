defmodule PhoenixBlog.Repo.Migrations.CreateImages do
  use Ecto.Migration

  def change do
    create table(:images, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :filename, :string, null: false
      add :storage_key, :string, null: false
      add :url, :string, null: false
      add :content_type, :string, null: false
      add :file_size, :integer
      add :alt_text, :string

      add :post_id, references(:posts, on_delete: :nilify_all)
      add :user_id, references(:authors, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:images, [:post_id])
    create index(:images, [:user_id])
    create index(:images, [:storage_key])
  end
end
